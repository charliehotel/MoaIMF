import Foundation

public actor NormalizationScanService: ScanServicing {
  private let ruleStore: StabilityRuleStore
  private let tracker: StabilityTracker
  private let engine: SafeRenameEngine
  private let history: HistoryStore
  private let scanner: FileTreeScanner
  private let planner = NormalizationPlanner()

  public init(
    ruleStore: StabilityRuleStore,
    tracker: StabilityTracker,
    engine: SafeRenameEngine,
    history: HistoryStore,
    excludedRoots: [URL] = []
  ) {
    self.ruleStore = ruleStore
    self.tracker = tracker
    self.engine = engine
    self.history = history
    scanner = FileTreeScanner(excludedRoots: excludedRoots)
  }

  public func scan(_ request: ScanRequest) async throws -> ScanServiceResult {
    try Task.checkCancellation()
    let recoveryOutcomes = try await engine.recoverPendingOperations()
    try await record(outcomes: recoveryOutcomes, root: request.root)
    let rules = try await ruleStore.allRules()
    let snapshot = try scanner.scan(
      root: request.root,
      matcher: StabilityExclusionMatcher(rules: rules)
    )
    try Task.checkCancellation()

    let stableEntries = await tracker.stableEntries(in: snapshot)
    let scopedIdentities = scopedIdentitySet(request: request, snapshot: snapshot)
    let stableIdentities = Set(stableEntries.map(\.identity))
    let eligibleIdentities: Set<FileIdentity>
    switch request.scope {
    case .manualPreview, .manualApply:
      eligibleIdentities = scopedIdentities
    default:
      eligibleIdentities = scopedIdentities.intersection(stableIdentities)
    }
    let fullPlan = try plan(snapshot: snapshot)
    let filteredPlan = NormalizationPlan(
      candidates: fullPlan.candidates.filter { eligibleIdentities.contains($0.identity) },
      collisions: filteredCollisions(
        fullPlan.collisions,
        snapshot: snapshot,
        scopedIdentities: scopedIdentities
      )
    )
    let deferredIdentities = Set(
      snapshot.entries.compactMap { entry in
        entry.stabilityExclusion == nil ? nil : entry.identity
      }
    )
    let summary = ScanContentSummary(
      totalEntryCount: snapshot.entries.count,
      nfcEntryCount: snapshot.entries.filter { UnicodeNormalizer.isNFC($0.rawName) }.count,
      nonNFCEntryCount: snapshot.entries.filter { !UnicodeNormalizer.isNFC($0.rawName) }.count
    )

    if request.scope == .manualPreview {
      return ScanServiceResult(
        summary: summary,
        plan: filteredPlan,
        deferredIdentities: deferredIdentities
      )
    }

    try await record(collisions: filteredPlan.collisions, root: request.root)
    try Task.checkCancellation()
    let outcomes = try await engine.apply(filteredPlan)
    try await record(outcomes: outcomes, root: request.root)
    let pendingIdentities = Set<FileIdentity>(
      snapshot.entries.compactMap { entry in
        guard
          scopedIdentities.contains(entry.identity),
          entry.stabilityExclusion == nil,
          !UnicodeNormalizer.isNFC(entry.rawName),
          !stableIdentities.contains(entry.identity)
        else {
          return nil
        }
        return entry.identity
      }
    )
    return ScanServiceResult(
      summary: summary,
      pendingIdentities: pendingIdentities,
      plan: filteredPlan,
      outcomes: outcomes,
      deferredIdentities: deferredIdentities
    )
  }

  private func scopedIdentitySet(
    request: ScanRequest,
    snapshot: ScanSnapshot
  ) -> Set<FileIdentity> {
    let scoped: Set<FileIdentity>
    switch request.scope {
    case .full:
      scoped = Set(snapshot.entries.map(\.identity))
    case .paths(let paths):
      scoped = Set(
        snapshot.entries.compactMap { entry in
          paths.contains(where: { contains(entry: entry.url, inEventPath: $0) })
            ? entry.identity : nil
        })
    case .candidates(let identities):
      scoped = Set(snapshot.entries.map(\.identity)).intersection(identities)
    case .manualPreview:
      scoped = Set(
        snapshot.entries.compactMap { $0.stabilityExclusion == nil ? $0.identity : nil }
      )
    case .manualApply(let approved):
      let allowed = Set(
        snapshot.entries.compactMap { $0.stabilityExclusion == nil ? $0.identity : nil }
      )
      scoped = allowed.intersection(approved)
    }
    return scoped.subtracting(request.excludedIdentities)
  }

  private func contains(entry: URL, inEventPath eventPath: URL) -> Bool {
    let entryPath = comparisonPath(entry)
    let parentPath = comparisonPath(eventPath)
    return entryPath == parentPath || entryPath.hasPrefix(parentPath + "/")
  }

  private func comparisonPath(_ url: URL) -> String {
    url.resolvingSymlinksInPath().standardizedFileURL.path
      .precomposedStringWithCanonicalMapping
  }

  private func filteredCollisions(
    _ collisions: [NormalizationCollision],
    snapshot: ScanSnapshot,
    scopedIdentities: Set<FileIdentity>
  ) -> [NormalizationCollision] {
    let scopedEntries = snapshot.entries.filter { scopedIdentities.contains($0.identity) }
    return collisions.filter { collision in
      scopedEntries.contains { entry in
        entry.url.deletingLastPathComponent() == collision.parent
          && collision.rawNames.contains(entry.rawName)
      }
    }
  }

  private func plan(snapshot: ScanSnapshot) throws -> NormalizationPlan {
    var entriesByParent: [URL: [SiblingEntry]] = [:]
    for entry in snapshot.entries {
      try Task.checkCancellation()
      let parent = entry.url.deletingLastPathComponent()
      entriesByParent[parent, default: []].append(
        SiblingEntry(
          identity: entry.identity,
          parent: parent,
          rawName: entry.rawName,
          isDirectory: entry.isDirectory
        )
      )
    }
    var candidates: [RenameCandidate] = []
    var collisions: [NormalizationCollision] = []
    for entries in entriesByParent.values {
      let partial = planner.plan(entries: entries, caseSensitive: snapshot.caseSensitive)
      candidates.append(contentsOf: partial.candidates)
      collisions.append(contentsOf: partial.collisions)
    }
    return NormalizationPlan(candidates: candidates, collisions: collisions)
  }

  private func record(collisions: [NormalizationCollision], root: URL) async throws {
    for collision in collisions {
      try Task.checkCancellation()
      _ = try await history.record(
        kind: .collision,
        rootIdentifier: root.path,
        previousURL: collision.parent,
        resultingURL: nil,
        reason: collision.rawNames.joined(separator: ", ")
      )
    }
  }

  private func record(outcomes: [RenameOutcome], root: URL) async throws {
    for outcome in outcomes {
      try Task.checkCancellation()
      let kind: HistoryEventKind = outcome.kind == .renamed ? .renamed : .error
      _ = try await history.record(
        kind: kind,
        rootIdentifier: root.path,
        previousURL: outcome.source,
        resultingURL: outcome.target,
        reason: outcome.reason ?? outcome.kind.rawValue
      )
    }
  }
}
