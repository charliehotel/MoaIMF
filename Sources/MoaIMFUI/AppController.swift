import AppKit
import Combine
import Foundation
import MoaIMFCore

@MainActor
public final class AppController: ObservableObject {
  @Published public private(set) var status: AppStatus = .noFolders
  @Published public private(set) var folders: [AppFolder] = []
  @Published public private(set) var stabilityRules: [StabilityExclusionRule] = []
  @Published public private(set) var history: [HistoryEvent] = []
  @Published public private(set) var preview: PreviewState?
  @Published public private(set) var folderScanReports: [UUID: FolderScanReport] = [:]
  @Published public private(set) var scanResult: ScanResultSummary?
  @Published public private(set) var alert: AppAlert?
  @Published public private(set) var isScanning = false
  @Published public private(set) var updateCheckStatus: AppUpdateStatus = .idle
  @Published public private(set) var availableUpdate: AppUpdate?
  @Published public private(set) var automaticAvailableUpdate: AppUpdate?
  @Published public private(set) var updateErrorMessage: String?

  public let loginItemManager: LoginItemManager
  public let languageManager: LanguageManager
  private let dataService: any AppDataServicing
  private let scanController: any AppScanControlling
  private let preferences: any AppPreferencesStoring
  private let notifier: SystemNotifier
  private let presentScanResult: @MainActor (ScanResultSummary) -> Void
  private let terminate: @MainActor () -> Void
  private let updateService: any AppUpdateServicing
  private let automaticallyCheckForUpdates: Bool
  private let currentVersion: String
  private let revealDownloadedUpdate: @MainActor (URL) -> Void
  private var updateCheckTask: Task<Void, Never>?

  public init(
    dataService: any AppDataServicing,
    scanController: any AppScanControlling,
    preferences: any AppPreferencesStoring = UserDefaultsAppPreferences(),
    loginItemManager: LoginItemManager = LoginItemManager(),
    languageManager: LanguageManager? = nil,
    notifier: SystemNotifier = SystemNotifier(),
    updateService: any AppUpdateServicing = NoopAppUpdateService(),
    automaticallyCheckForUpdates: Bool = false,
    currentVersion: String = AboutAppInfo.current().version,
    revealDownloadedUpdate: (@MainActor (URL) -> Void)? = nil,
    presentScanResult: (@MainActor (ScanResultSummary) -> Void)? = nil,
    terminate: @escaping @MainActor () -> Void
  ) {
    let resolvedLanguageManager = languageManager ?? LanguageManager(preferences: preferences)
    self.dataService = dataService
    self.scanController = scanController
    self.preferences = preferences
    self.loginItemManager = loginItemManager
    self.languageManager = resolvedLanguageManager
    self.notifier = notifier
    self.updateService = updateService
    self.automaticallyCheckForUpdates = automaticallyCheckForUpdates
    self.currentVersion = currentVersion
    self.revealDownloadedUpdate =
      revealDownloadedUpdate ?? { downloadedURL in
        NSWorkspace.shared.activateFileViewerSelecting([downloadedURL])
      }
    self.presentScanResult =
      presentScanResult ?? { summary in
        AppWindowManager.shared.showScanResult(
          summary: summary,
          languageManager: resolvedLanguageManager
        )
      }
    self.terminate = terminate
  }

  public var isPaused: Bool { preferences.isPaused }

  public func load() async {
    do {
      folders = try await dataService.loadFolders()
      stabilityRules = try await dataService.loadRules()
      history = try await dataService.loadHistory().sorted { $0.timestamp > $1.timestamp }
      if preferences.isPaused {
        await scanController.pause()
      } else {
        await scanController.start(roots: enabledRoots)
      }
      loginItemManager.refresh()
      updateStatus()
      startAutomaticUpdateChecks()
    } catch {
      handle(error)
    }
  }

  public func previewExisting(in root: URL) async {
    await withScanning {
      let result = try await scanController.preview(root: root)
      preview = PreviewState(root: root, result: result)
      if !result.plan.collisions.isEmpty {
        alert = AppAlert(localizationKey: "alert.collision")
        await notifier.notify(.collision)
      } else {
        alert = nil
      }
    }
  }

  public func scanFolder(id: UUID) async {
    guard let folder = folders.first(where: { $0.id == id }) else { return }
    await withScanning {
      let result = try await scanController.preview(root: folder.url)
      folderScanReports[id] = FolderScanReport(root: folder.url, scannedAt: Date(), result: result)
      if !result.plan.collisions.isEmpty {
        alert = AppAlert(localizationKey: "alert.collision")
        await notifier.notify(.collision)
      } else {
        alert = nil
      }
    }
  }

  public func applyPreview() async {
    guard let preview else { return }
    await withScanning {
      let identities = Set(preview.result.plan.candidates.map(\.identity))
      _ = try await scanController.apply(root: preview.root, identities: identities)
      try await addFolderIfNeeded(preview.root, mode: .allItems)
      self.preview = nil
      alert = nil
    }
  }

  public func watchNewItemsOnly(in root: URL) async {
    await withScanning {
      try await addFolderIfNeeded(root, mode: .newItemsOnly)
      preview = nil
      alert = nil
    }
  }

  public func removeFolder(id: UUID) async {
    do {
      try await dataService.removeFolder(id: id)
      folders = try await dataService.loadFolders()
      folderScanReports[id] = nil
      await scanController.updateRoots(enabledRoots)
      updateStatus()
    } catch { handle(error) }
  }

  public func setFolderEnabled(id: UUID, enabled: Bool) async {
    do {
      try await dataService.setFolderEnabled(id: id, enabled: enabled)
      folders = try await dataService.loadFolders()
      await scanController.updateRoots(enabledRoots)
      updateStatus()
    } catch { handle(error) }
  }

  public func reselectFolder(id: UUID, url: URL) async {
    do {
      try await dataService.reselectFolder(id: id, url: url)
      folders = try await dataService.loadFolders()
      folderScanReports[id] = nil
      await scanController.updateRoots(enabledRoots)
      alert = nil
      updateStatus()
    } catch { handle(error) }
  }

  public func scanAll() async {
    var reports: [FolderScanReport] = []
    await withScanning(
      {
        for folder in folders where folder.isEnabled && folder.status == .available {
          let preview = try await scanController.preview(root: folder.url)
          let identities = Set(preview.plan.candidates.map(\.identity))
          let result = try await scanController.apply(
            root: folder.url,
            identities: identities
          )
          let report = FolderScanReport(
            root: folder.url,
            scannedAt: Date(),
            result: result
          )
          reports.append(report)
          self.folderScanReports[folder.id] = report
        }
        self.history = try await self.dataService.loadHistory().sorted {
          $0.timestamp > $1.timestamp
        }
        self.alert = nil
        let summary = ScanResultSummary(reports: reports)
        self.scanResult = summary
        self.presentScanResult(summary)
      },
      onError: { error in
        let summary = ScanResultSummary(
          reports: reports,
          errorMessage: error.localizedDescription
        )
        self.scanResult = summary
        self.presentScanResult(summary)
      })
  }

  @discardableResult
  public func checkForUpdates(manually: Bool = true) async -> AppUpdateCheckResult? {
    guard updateCheckStatus != .checking, updateCheckStatus != .downloading else { return nil }

    updateCheckStatus = .checking
    updateErrorMessage = nil
    do {
      let result = try await updateService.check(currentVersion: currentVersion)
      switch result {
      case .current:
        availableUpdate = nil
        automaticAvailableUpdate = nil
        updateCheckStatus = .current
      case .available(let update):
        availableUpdate = update
        automaticAvailableUpdate = update
        updateCheckStatus = .available
      }
      return manually ? result : nil
    } catch {
      updateCheckStatus = .failed
      updateErrorMessage = error.localizedDescription
      return nil
    }
  }

  public func downloadAvailableUpdate() async {
    guard let update = availableUpdate, updateCheckStatus != .downloading else { return }

    updateCheckStatus = .downloading
    updateErrorMessage = nil
    do {
      let downloadedURL = try await updateService.download(update)
      updateCheckStatus = .downloaded
      revealDownloadedUpdate(downloadedURL)
    } catch {
      updateCheckStatus = .failed
      updateErrorMessage = error.localizedDescription
    }
  }

  public func setPaused(_ paused: Bool) async {
    preferences.isPaused = paused
    if paused { await scanController.pause() } else { await scanController.resume() }
    updateStatus()
  }

  public func addRule(kind: StabilityRuleKind, pattern: String) async {
    do {
      _ = try await dataService.addRule(kind: kind, pattern: pattern)
      stabilityRules = try await dataService.loadRules()
      await scanController.rulesDidChange()
      alert = nil
    } catch {
      alert = AppAlert(localizationKey: "stability.invalid", detail: error.localizedDescription)
    }
  }

  public func removeRule(id: String) async {
    do {
      try await dataService.removeRule(id: id)
      stabilityRules = try await dataService.loadRules()
      await scanController.rulesDidChange()
      alert = nil
    } catch {
      alert = AppAlert(localizationKey: "stability.invalid", detail: error.localizedDescription)
    }
  }

  public func quit() async {
    updateCheckTask?.cancel()
    updateCheckTask = nil
    await scanController.shutdown()
    await dataService.shutdown()
    terminate()
  }

  public func dismissAlert() {
    alert = nil
    updateStatus()
  }

  public var todaysRenameCount: Int {
    let calendar = Calendar.current
    return history.filter { $0.kind == .renamed && calendar.isDateInToday($0.timestamp) }.count
  }

  public var lastActivityDate: Date? { history.map(\.timestamp).max() }

  private var enabledRoots: [URL: Set<FileIdentity>] {
    Dictionary(
      uniqueKeysWithValues:
        folders
        .filter { $0.isEnabled && $0.status == .available }
        .map { ($0.url, $0.excludedExistingIdentities) }
    )
  }

  private func addFolderIfNeeded(
    _ url: URL,
    mode: WatchedFolderNormalizationMode
  ) async throws {
    if !folders.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
      _ = try await dataService.addFolder(url: url, mode: mode)
    }
    folders = try await dataService.loadFolders()
    await scanController.updateRoots(enabledRoots)
    if !preferences.isPaused { await scanController.resume() }
  }

  private func withScanning(
    _ operation: () async throws -> Void,
    onError: ((Error) -> Void)? = nil
  ) async {
    isScanning = true
    status = .scanning
    do {
      try await operation()
    } catch {
      handle(error)
      onError?(error)
    }
    isScanning = false
    updateStatus()
  }

  private func updateStatus() {
    if isScanning {
      status = .scanning
    } else if preferences.isPaused {
      status = .paused
    } else if folders.contains(where: { $0.status == .permissionRequired }) {
      status = .permissionRequired
    } else if folders.contains(where: { $0.status == .disconnected }) {
      status = .disconnected
    } else if alert?.localizationKey == "alert.permission" {
      status = .permissionRequired
    } else if alert != nil {
      status = .attention
    } else if folders.isEmpty {
      status = .noFolders
    } else {
      status = .watching
    }
  }

  private func startAutomaticUpdateChecks() {
    guard automaticallyCheckForUpdates, updateCheckTask == nil else { return }

    updateCheckTask = Task { [weak self] in
      await self?.checkForUpdates(manually: false)
      while !Task.isCancelled {
        do {
          try await Task.sleep(for: .seconds(24 * 60 * 60))
        } catch {
          return
        }
        guard !Task.isCancelled else { return }
        await self?.checkForUpdates(manually: false)
      }
    }
  }

  private func handle(_ error: Error) {
    let key: String
    if error as? WatchedFolderError == .accessDenied {
      key = "alert.permission"
      Task { await notifier.notify(.permissionLost) }
    } else {
      key = "alert.generic"
    }
    alert = AppAlert(localizationKey: key, detail: error.localizedDescription)
    updateStatus()
  }
}
