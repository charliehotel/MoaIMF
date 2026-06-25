import Foundation
import MoaIMFCore

@MainActor
public enum MoaIMFEnvironment {
  public static func makeController(
    preferences: any AppPreferencesStoring = UserDefaultsAppPreferences(),
    languageManager: LanguageManager? = nil,
    terminate: @escaping @MainActor () -> Void
  ) -> AppController {
    let support = applicationSupportDirectory()
    let folderStore = WatchedFolderStore(
      fileURL: support.appendingPathComponent("watched-folders.json"))
    let ruleStore = StabilityRuleStore(
      fileURL: support.appendingPathComponent("stability-rules.json"))
    let historyStore = HistoryStore(
      fileURL: support.appendingPathComponent("history.jsonl"))
    let scanService = NormalizationScanService(
      ruleStore: ruleStore,
      tracker: StabilityTracker(),
      engine: SafeRenameEngine(
        journal: RecoveryJournal(directory: support.appendingPathComponent("recovery"))),
      history: historyStore,
      excludedRoots: [support]
    )
    let coordinator = ScanCoordinator(
      roots: [],
      eventMonitor: FSEventMonitor(),
      volumeMonitor: VolumeMonitor(),
      scanService: scanService
    )
    return AppController(
      dataService: LocalAppDataService(
        folderStore: folderStore,
        ruleStore: ruleStore,
        historyStore: historyStore
      ),
      scanController: CoordinatorScanController(
        coordinator: coordinator,
        scanService: scanService
      ),
      preferences: preferences,
      languageManager: languageManager,
      terminate: terminate
    )
  }

  private static func applicationSupportDirectory() -> URL {
    let base =
      FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first
      ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(
        "Library/Application Support")
    return base.appendingPathComponent("MoaIMF", isDirectory: true)
  }
}
