import Foundation
import MoaIMFCore

@MainActor
public final class LocalAppDataService: AppDataServicing {
  private let folderStore: WatchedFolderStore
  private let ruleStore: StabilityRuleStore
  private let historyStore: HistoryStore

  public init(
    folderStore: WatchedFolderStore,
    ruleStore: StabilityRuleStore,
    historyStore: HistoryStore
  ) {
    self.folderStore = folderStore
    self.ruleStore = ruleStore
    self.historyStore = historyStore
  }

  public func loadFolders() async throws -> [AppFolder] {
    let folders = try await folderStore.folders()
    let active = try await folderStore.activateEnabledFolders()
    let history = try await historyStore.load().events
    var result: [AppFolder] = []
    for folder in folders {
      let url = try await folderStore.resolvedURL(id: folder.id)
      let rootHistory = history.filter { $0.rootIdentifier == url.path }
      let status: WatchedFolderStatus =
        folder.isEnabled && folder.status == .available && active[folder.id] == nil
        ? .permissionRequired : folder.status
      result.append(
        AppFolder(
          id: folder.id,
          url: url,
          displayName: folder.displayName,
          isEnabled: folder.isEnabled,
          status: status,
          lastScan: rootHistory.map(\.timestamp).max(),
          collisionCount: rootHistory.filter { $0.kind == .collision }.count,
          normalizationMode: folder.normalizationMode,
          excludedExistingIdentities: folder.excludedExistingIdentities
        ))
    }
    return result.sorted { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
  }

  public func loadRules() async throws -> [StabilityExclusionRule] {
    try await ruleStore.allRules()
  }

  public func loadHistory() async throws -> [HistoryEvent] {
    try await historyStore.load().events
  }

  public func addFolder(
    url: URL,
    mode: WatchedFolderNormalizationMode
  ) async throws -> AppFolder {
    let added = try await folderStore.add(url: url, mode: mode)
    return try await folder(id: added.id)
  }

  public func removeFolder(id: UUID) async throws {
    try await folderStore.remove(id: id)
  }

  public func setFolderEnabled(id: UUID, enabled: Bool) async throws {
    try await folderStore.setEnabled(id: id, enabled: enabled)
  }

  public func reselectFolder(id: UUID, url: URL) async throws {
    try await folderStore.reselect(id: id, url: url)
  }

  public func addRule(
    kind: StabilityRuleKind,
    pattern: String
  ) async throws -> StabilityExclusionRule {
    try await ruleStore.add(kind: kind, pattern: pattern)
  }

  public func removeRule(id: String) async throws {
    try await ruleStore.remove(id: id)
  }

  public func shutdown() async {
    await folderStore.deactivateAllFolders()
  }

  private func folder(id: UUID) async throws -> AppFolder {
    guard let folder = try await loadFolders().first(where: { $0.id == id }) else {
      throw WatchedFolderError.folderNotFound
    }
    return folder
  }
}
