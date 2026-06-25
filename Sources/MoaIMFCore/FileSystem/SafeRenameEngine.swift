import Foundation

struct RenameEngineHooks: Sendable {
  let directMove: @Sendable (URL, URL) throws -> Void
  let verificationOverride: @Sendable (URL, FileIdentity) throws -> Bool?
  let afterTemporaryMove: @Sendable () throws -> Void
  let afterCandidate: @Sendable () async -> Void

  init(
    directMove: @escaping @Sendable (URL, URL) throws -> Void = {
      try FileManager.default.moveItem(at: $0, to: $1)
    },
    verificationOverride: @escaping @Sendable (URL, FileIdentity) throws -> Bool? = { _, _ in nil },
    afterTemporaryMove: @escaping @Sendable () throws -> Void = {},
    afterCandidate: @escaping @Sendable () async -> Void = {}
  ) {
    self.directMove = directMove
    self.verificationOverride = verificationOverride
    self.afterTemporaryMove = afterTemporaryMove
    self.afterCandidate = afterCandidate
  }
}

public actor SafeRenameEngine {
  let journal: RecoveryJournal
  private let hooks: RenameEngineHooks
  let fileSystem = RenameFileSystem()
  private var unsupportedVolumes: Set<String> = []

  public init(journal: RecoveryJournal) {
    self.journal = journal
    hooks = RenameEngineHooks()
  }

  init(journal: RecoveryJournal, hooks: RenameEngineHooks) {
    self.journal = journal
    self.hooks = hooks
  }

  public func isVolumeUnsupported(_ volume: String) -> Bool {
    unsupportedVolumes.contains(volume)
  }

  public func apply(_ plan: NormalizationPlan) async throws -> [RenameOutcome] {
    let candidates = plan.candidates.sorted {
      let leftDepth = $0.source.pathComponents.count
      let rightDepth = $1.source.pathComponents.count
      return leftDepth == rightDepth ? $0.source.path < $1.source.path : leftDepth > rightDepth
    }
    var outcomes: [RenameOutcome] = []
    for candidate in candidates {
      try Task.checkCancellation()
      let target = candidate.source.deletingLastPathComponent()
        .appendingPathComponent(candidate.targetName)
      let outcome: RenameOutcome
      if isCollisionParticipant(candidate, collisions: plan.collisions) {
        outcome = result(
          candidate, target: target, kind: .failed, reason: "Normalization collision")
      } else if unsupportedVolumes.contains(candidate.identity.volume) {
        outcome = result(candidate, target: target, kind: .failed, reason: "Unsupported volume")
      } else {
        outcome = await apply(candidate)
      }
      outcomes.append(outcome)
      await hooks.afterCandidate()
    }
    return outcomes
  }

  private func apply(_ candidate: RenameCandidate) async -> RenameOutcome {
    let target: URL
    do {
      target = try fileSystem.preflight(candidate)
    } catch {
      return result(
        candidate, target: fallbackTarget(candidate), kind: .failed, reason: describe(error))
    }

    do {
      try hooks.directMove(candidate.source, target)
      if try verified(target, rawTargetName: candidate.targetName, identity: candidate.identity) {
        return result(candidate, target: target, kind: .renamed, reason: nil)
      }
      if try fileSystem.hasIdentity(candidate.identity, at: candidate.source) {
        return await applyFallback(
          candidate, target: target, directFailure: "Direct rename was not persisted")
      }
      unsupportedVolumes.insert(candidate.identity.volume)
      return await rollbackDirect(candidate, target: target, reason: "Post-verification failed")
    } catch {
      do {
        if try verified(target, rawTargetName: candidate.targetName, identity: candidate.identity) {
          return result(candidate, target: target, kind: .renamed, reason: nil)
        }
      } catch {
        return result(candidate, target: target, kind: .failed, reason: describe(error))
      }
      return await applyFallback(candidate, target: target, directFailure: describe(error))
    }
  }

  private func applyFallback(
    _ candidate: RenameCandidate,
    target: URL,
    directFailure: String
  ) async -> RenameOutcome {
    let record = recoveryRecord(candidate, target: target)
    do {
      try await journal.write(record)
      try fileSystem.moveExclusively(from: candidate.source, to: record.temporaryURL)
      try await journal.write(record.updating(phase: .temporary))
      try hooks.afterTemporaryMove()
      try fileSystem.moveExclusively(
        from: record.temporaryURL,
        toParent: target.deletingLastPathComponent(),
        rawName: candidate.targetName
      )
      guard try verified(target, rawTargetName: candidate.targetName, identity: candidate.identity)
      else {
        unsupportedVolumes.insert(candidate.identity.volume)
        throw RenameFileSystemError.verificationFailed(target)
      }
      guard
        try fileSystem.isVerifiedTarget(
          target,
          rawTargetName: candidate.targetName,
          identity: candidate.identity
        )
      else {
        throw RenameFileSystemError.verificationFailed(target)
      }
      try await finish(record.updating(phase: .completed))
      return result(candidate, target: target, kind: .renamed, reason: directFailure)
    } catch {
      do {
        if try await restore(record) {
          try await finish(record.updating(phase: .rolledBack))
          return result(candidate, target: target, kind: .rolledBack, reason: describe(error))
        }
      } catch {
        return result(candidate, target: target, kind: .failed, reason: describe(error))
      }
      return result(candidate, target: target, kind: .failed, reason: describe(error))
    }
  }

  private func rollbackDirect(
    _ candidate: RenameCandidate,
    target: URL,
    reason: String
  ) async -> RenameOutcome {
    let record = recoveryRecord(candidate, target: target)
    do {
      try await journal.write(record)
      guard try await restore(record) else {
        return result(candidate, target: target, kind: .failed, reason: reason)
      }
      try await finish(record.updating(phase: .rolledBack))
      return result(candidate, target: target, kind: .rolledBack, reason: reason)
    } catch {
      return result(candidate, target: target, kind: .failed, reason: describe(error))
    }
  }

  private func verified(_ target: URL, rawTargetName: String, identity: FileIdentity) throws -> Bool
  {
    if let override = try hooks.verificationOverride(target, identity) { return override }
    return try fileSystem.isVerifiedTarget(target, rawTargetName: rawTargetName, identity: identity)
  }

  private func recoveryRecord(_ candidate: RenameCandidate, target: URL) -> RenameRecoveryRecord {
    let operationID = UUID()
    let temporary = candidate.source.deletingLastPathComponent()
      .appendingPathComponent(".moaimf-\(operationID.uuidString)-temporary")
    return RenameRecoveryRecord(
      operationID: operationID,
      identity: candidate.identity,
      originalURL: candidate.source,
      temporaryURL: temporary,
      targetURL: target,
      targetName: candidate.targetName,
      phase: .planned
    )
  }

  private func isCollisionParticipant(
    _ candidate: RenameCandidate,
    collisions: [NormalizationCollision]
  ) -> Bool {
    let parent = candidate.source.deletingLastPathComponent()
    return collisions.contains { collision in
      fileSystem.sameDirectory(parent, collision.parent)
        && collision.rawNames.contains {
          fileSystem.rawEqual($0, candidate.source.lastPathComponent)
        }
    }
  }

  private func fallbackTarget(_ candidate: RenameCandidate) -> URL {
    candidate.source.deletingLastPathComponent().appendingPathComponent(candidate.targetName)
  }

  private func result(
    _ candidate: RenameCandidate,
    target: URL,
    kind: RenameOutcomeKind,
    reason: String?
  ) -> RenameOutcome {
    RenameOutcome(
      identity: candidate.identity,
      source: candidate.source,
      target: target,
      kind: kind,
      reason: reason
    )
  }

  private func describe(_ error: Error) -> String {
    (error as? LocalizedError)?.errorDescription ?? String(describing: error)
  }
}
