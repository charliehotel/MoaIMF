import MoaIMFCore
import XCTest

@testable import MoaIMFUI

@MainActor
final class AppControllerTests: XCTestCase {
  func testFirstRunLoadsNoFoldersAndBuiltInRules() async {
    let context = TestContext()

    await context.controller.load()

    XCTAssertEqual(context.controller.status, .noFolders)
    XCTAssertTrue(context.controller.folders.isEmpty)
    XCTAssertEqual(context.controller.stabilityRules, context.data.rules)
  }

  func testPreviewDoesNotPersistOrMutateNames() async {
    let context = TestContext()
    context.scanner.previewResult = ScanServiceResult(
      plan: NormalizationPlan(
        candidates: [candidate(name: "한글.txt")],
        collisions: [collision()]
      )
    )

    await context.controller.previewExisting(in: URL(fileURLWithPath: "/tmp/Downloads"))

    XCTAssertEqual(context.controller.preview?.nonNFCCount, 1)
    XCTAssertEqual(context.controller.preview?.collisionCount, 1)
    XCTAssertTrue(context.data.addedURLs.isEmpty)
    XCTAssertEqual(context.scanner.applyCallCount, 0)
  }

  func testApplyPreviewAddsFolderAndStartsWatching() async {
    let context = TestContext()
    let root = URL(fileURLWithPath: "/tmp/Downloads")
    context.scanner.previewResult = ScanServiceResult(
      plan: NormalizationPlan(candidates: [candidate(name: "한글.txt")], collisions: [])
    )
    await context.controller.previewExisting(in: root)

    await context.controller.applyPreview()

    XCTAssertEqual(context.scanner.applyCallCount, 1)
    XCTAssertEqual(context.data.addedURLs, [root])
    XCTAssertEqual(context.data.addedModes, [.allItems])
    XCTAssertEqual(context.controller.status, .watching)
  }

  func testWatchNewOnlyAddsFolderWithoutApplyingPreview() async {
    let context = TestContext()
    let root = URL(fileURLWithPath: "/tmp/Downloads")

    await context.controller.watchNewItemsOnly(in: root)

    XCTAssertEqual(context.data.addedURLs, [root])
    XCTAssertEqual(context.data.addedModes, [.newItemsOnly])
    XCTAssertEqual(context.scanner.applyCallCount, 0)
    XCTAssertEqual(context.scanner.lastRoots[root]?.count, 1)
  }

  func testPermissionDenialSurfacesLocalizedAlertKey() async {
    let context = TestContext()
    context.data.addError = WatchedFolderError.accessDenied

    await context.controller.watchNewItemsOnly(in: URL(fileURLWithPath: "/tmp/Denied"))

    XCTAssertEqual(context.controller.alert?.localizationKey, "alert.permission")
    XCTAssertEqual(context.controller.status, .permissionRequired)
  }

  func testPausePersistsAndResumeRestartsCoordinator() async {
    let context = TestContext()
    context.data.loadedFolders = [folder()]
    await context.controller.load()

    await context.controller.setPaused(true)
    XCTAssertTrue(context.preferences.isPaused)
    XCTAssertEqual(context.controller.status, .paused)
    XCTAssertEqual(context.scanner.pauseCallCount, 1)

    await context.controller.setPaused(false)
    XCTAssertFalse(context.preferences.isPaused)
    XCTAssertEqual(context.scanner.resumeCallCount, 1)
  }

  func testScanFolderPublishesFolderReportWithoutMutatingPreview() async throws {
    let context = TestContext()
    let watched = folder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000123") ?? UUID())
    context.data.loadedFolders = [watched]
    context.scanner.previewResult = ScanServiceResult(
      summary: ScanContentSummary(totalEntryCount: 8, nfcEntryCount: 5, nonNFCEntryCount: 3),
      plan: NormalizationPlan(
        candidates: [candidate(name: "한글.txt"), candidate(name: "다른.txt")],
        collisions: []
      ),
      deferredIdentities: [FileIdentity(volume: "volume", resource: "deferred")]
    )
    await context.controller.load()

    await context.controller.scanFolder(id: watched.id)

    let report = try XCTUnwrap(context.controller.folderScanReports[watched.id])
    XCTAssertEqual(report.totalCount, 8)
    XCTAssertEqual(report.nfcCount, 5)
    XCTAssertEqual(report.nonNFCCount, 3)
    XCTAssertEqual(report.actionableNonNFCCount, 2)
    XCTAssertEqual(report.deferredCount, 1)
    XCTAssertNil(context.controller.preview)
    XCTAssertTrue(context.data.addedURLs.isEmpty)
    XCTAssertEqual(context.scanner.applyCallCount, 0)
  }

  func testScanAllAppliesCandidatesAndReloadsRecentHistory() async throws {
    let context = TestContext()
    let watched = folder()
    let item = candidate(name: "한글.txt")
    context.data.loadedFolders = [watched]
    context.scanner.previewResult = ScanServiceResult(
      plan: NormalizationPlan(candidates: [item], collisions: []))

    await context.controller.load()
    let event = HistoryEvent(
      timestamp: Date(),
      kind: .renamed,
      rootIdentifier: watched.url.path,
      previousURL: item.source,
      resultingURL: item.source.deletingLastPathComponent().appendingPathComponent(item.targetName),
      reason: "manual scan"
    )
    context.data.history = [event]

    await context.controller.scanAll()

    XCTAssertEqual(context.scanner.applyCallCount, 1)
    XCTAssertEqual(context.scanner.appliedIdentities, [[item.identity]])
    XCTAssertEqual(context.controller.history, [event])
    XCTAssertFalse(context.controller.isScanning)
  }

  func testScanAllPublishesUserVisibleResultSummary() async throws {
    let context = TestContext()
    let watched = folder()
    let item = candidate(name: "한글.txt")
    let renamed = RenameOutcome(
      identity: item.identity,
      source: item.source,
      target: item.source.deletingLastPathComponent().appendingPathComponent(item.targetName),
      kind: .renamed,
      reason: nil
    )
    context.data.loadedFolders = [watched]
    context.scanner.previewResult = ScanServiceResult(
      summary: ScanContentSummary(totalEntryCount: 4, nfcEntryCount: 3, nonNFCEntryCount: 1),
      plan: NormalizationPlan(candidates: [item], collisions: [])
    )
    context.scanner.applyResult = ScanServiceResult(
      summary: ScanContentSummary(totalEntryCount: 4, nfcEntryCount: 3, nonNFCEntryCount: 1),
      plan: NormalizationPlan(candidates: [item], collisions: []),
      outcomes: [renamed],
      deferredIdentities: [FileIdentity(volume: "volume", resource: "deferred")]
    )

    await context.controller.load()
    await context.controller.scanAll()

    let summary = try XCTUnwrap(context.controller.scanResult)
    XCTAssertEqual(summary.scannedCount, 4)
    XCTAssertEqual(summary.candidateCount, 1)
    XCTAssertEqual(summary.renamedCount, 1)
    XCTAssertEqual(summary.renamedOutcomes, [renamed])
    XCTAssertEqual(summary.failedCount, 0)
    XCTAssertEqual(summary.deferredCount, 1)
    XCTAssertEqual(context.presentedScanResults, [summary])
  }

  func testScanAllPublishesFailureInUserVisibleResultSummary() async throws {
    let context = TestContext()
    context.data.loadedFolders = [folder()]
    context.scanner.previewError = ScanTestError.failed

    await context.controller.load()
    await context.controller.scanAll()

    let summary = try XCTUnwrap(context.controller.scanResult)
    XCTAssertEqual(summary.errorMessage, "The scan failed in the test.")
    XCTAssertEqual(context.controller.alert?.localizationKey, "alert.generic")
    XCTAssertEqual(context.presentedScanResults, [summary])
  }

  func testScanAllDefaultPresenterShowsResultWindow() async {
    let data = FakeAppDataService()
    let scanner = FakeAppScanController()
    data.loadedFolders = [folder()]
    let controller = AppController(
      dataService: data,
      scanController: scanner,
      preferences: FakePreferences(),
      loginItemManager: LoginItemManager(service: FakeLoginService()),
      notifier: SystemNotifier(center: FakeNotificationService()),
      terminate: {}
    )

    await controller.load()
    await controller.scanAll()

    XCTAssertTrue(AppWindowManager.shared.isScanResultVisible)
    AppWindowManager.shared.closeAll()
  }

  func testManualUpdateCheckPublishesAvailableRelease() async throws {
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    let context = TestContext(
      updateService: FakeAppUpdateService(result: .available(update))
    )

    await context.controller.checkForUpdates()

    XCTAssertEqual(context.controller.updateCheckStatus, .available)
    XCTAssertEqual(context.controller.availableUpdate, update)
    XCTAssertNil(context.controller.updateErrorMessage)
  }

  func testScanAllRenamesOnDiskImmediatelyAndPersistsHistory() async throws {
    let fixture = try ManualScanFixture()
    defer { fixture.remove() }
    let source = fixture.root.appendingPathComponent("한글.txt")
    try Data("payload".utf8).write(to: source)

    let data = HistoryBackedDataService(
      root: fixture.root,
      ruleStore: fixture.ruleStore,
      history: fixture.history
    )
    let scanController = DirectAppScanController(service: fixture.makeService())
    let controller = AppController(
      dataService: data,
      scanController: scanController,
      preferences: FakePreferences(),
      loginItemManager: LoginItemManager(service: FakeLoginService()),
      notifier: SystemNotifier(center: FakeNotificationService()),
      presentScanResult: { _ in },
      terminate: {}
    )

    await controller.load()
    await controller.scanAll()

    let names = try fixture.rawNames()
    XCTAssertFalse(names.containsRawBytes("한글.txt"))
    XCTAssertTrue(names.containsRawBytes("한글.txt"))
    let events = try await fixture.history.load().events
    XCTAssertEqual(events.map(\.kind), [.renamed])
    XCTAssertEqual(controller.history, events)
  }

  func testRootProblemsAndCollisionsProduceAttentionStates() async {
    let disconnected = TestContext()
    disconnected.data.loadedFolders = [folder(status: .disconnected)]
    await disconnected.controller.load()
    XCTAssertEqual(disconnected.controller.status, .disconnected)

    let permission = TestContext()
    permission.data.loadedFolders = [folder(status: .permissionRequired)]
    await permission.controller.load()
    XCTAssertEqual(permission.controller.status, .permissionRequired)

    let collisionContext = TestContext()
    collisionContext.data.loadedFolders = [folder()]
    collisionContext.scanner.previewResult = ScanServiceResult(
      plan: NormalizationPlan(candidates: [], collisions: [collision()])
    )
    await collisionContext.controller.load()
    await collisionContext.controller.previewExisting(
      in: URL(fileURLWithPath: "/tmp/Downloads"))
    XCTAssertEqual(collisionContext.controller.status, .attention)
  }

  func testUserRulesCanBeAddedAndRemovedAndTriggerReconciliation() async throws {
    let context = TestContext()

    await context.controller.addRule(kind: .suffix, pattern: ".aria2")
    let added = try XCTUnwrap(context.controller.stabilityRules.last)
    await context.controller.removeRule(id: added.id)

    XCTAssertEqual(context.data.addedRulePatterns, [".aria2"])
    XCTAssertEqual(context.data.removedRuleIDs, [added.id])
    XCTAssertEqual(context.scanner.rulesChangedCallCount, 2)
  }

  func testInvalidRuleDoesNotMutateList() async {
    let context = TestContext()

    await context.controller.addRule(kind: .suffix, pattern: "")

    XCTAssertTrue(context.controller.stabilityRules.isEmpty)
    XCTAssertEqual(context.controller.alert?.localizationKey, "stability.invalid")
  }

  func testDismissingAttentionRestoresDerivedStatus() async {
    let context = TestContext()
    context.data.loadedFolders = [folder()]
    context.scanner.previewResult = ScanServiceResult(
      plan: NormalizationPlan(candidates: [], collisions: [collision()]))
    await context.controller.load()
    await context.controller.previewExisting(in: URL(fileURLWithPath: "/tmp/Downloads"))

    context.controller.dismissAlert()

    XCTAssertEqual(context.controller.status, .watching)
  }

  func testQuitWaitsForShutdownBeforeTermination() async {
    let context = TestContext()

    await context.controller.quit()

    XCTAssertEqual(context.scanner.shutdownCallCount, 1)
    XCTAssertTrue(context.didTerminate)
  }
}

@MainActor
private final class TestContext {
  let data = FakeAppDataService()
  let scanner = FakeAppScanController()
  let preferences = FakePreferences()
  private let updateService: any AppUpdateServicing
  private(set) var presentedScanResults: [ScanResultSummary] = []
  var didTerminate = false

  init(updateService: any AppUpdateServicing = NoopAppUpdateService()) {
    self.updateService = updateService
  }

  lazy var controller = AppController(
    dataService: data,
    scanController: scanner,
    preferences: preferences,
    loginItemManager: LoginItemManager(service: FakeLoginService()),
    notifier: SystemNotifier(center: FakeNotificationService()),
    updateService: updateService,
    presentScanResult: { [weak self] summary in
      self?.presentedScanResults.append(summary)
    },
    terminate: { [weak self] in self?.didTerminate = true }
  )
}

@MainActor
private final class FakeAppUpdateService: AppUpdateServicing {
  let result: AppUpdateCheckResult

  init(result: AppUpdateCheckResult) {
    self.result = result
  }

  func check(currentVersion: String) async throws -> AppUpdateCheckResult { result }

  func download(_ update: AppUpdate) async throws -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent(update.assetName)
  }
}

@MainActor
private final class FakeAppDataService: AppDataServicing {
  var loadedFolders: [AppFolder] = []
  var rules: [StabilityExclusionRule] = StabilityExclusionMatcher.builtInRules
  var history: [HistoryEvent] = []
  var addError: Error?
  private(set) var addedURLs: [URL] = []
  private(set) var addedModes: [WatchedFolderNormalizationMode] = []
  private(set) var addedRulePatterns: [String] = []
  private(set) var removedRuleIDs: [String] = []

  func loadFolders() async throws -> [AppFolder] { loadedFolders }
  func loadRules() async throws -> [StabilityExclusionRule] { rules }
  func loadHistory() async throws -> [HistoryEvent] { history }

  func addFolder(
    url: URL,
    mode: WatchedFolderNormalizationMode
  ) async throws -> AppFolder {
    if let addError { throw addError }
    addedURLs.append(url)
    addedModes.append(mode)
    let baseline: Set<FileIdentity> =
      mode == .newItemsOnly
      ? [FileIdentity(volume: "volume", resource: "existing")]
      : []
    let newFolder = AppFolder(
      id: UUID(),
      url: url,
      displayName: url.lastPathComponent,
      isEnabled: true,
      status: .available,
      normalizationMode: mode,
      excludedExistingIdentities: baseline
    )
    loadedFolders.append(newFolder)
    return newFolder
  }

  func removeFolder(id: UUID) async throws { loadedFolders.removeAll { $0.id == id } }
  func setFolderEnabled(id: UUID, enabled: Bool) async throws {}
  func reselectFolder(id: UUID, url: URL) async throws {}

  func addRule(kind: StabilityRuleKind, pattern: String) async throws -> StabilityExclusionRule {
    try StabilityExclusionMatcher.validate(kind: kind, pattern: pattern)
    addedRulePatterns.append(pattern)
    let rule = StabilityExclusionRule(
      id: UUID().uuidString, kind: kind, pattern: pattern, source: .user)
    rules.append(rule)
    return rule
  }

  func removeRule(id: String) async throws {
    removedRuleIDs.append(id)
    rules.removeAll { $0.id == id }
  }

  func shutdown() async {}
}

@MainActor
private final class FakeAppScanController: AppScanControlling {
  var previewResult = ScanServiceResult()
  var applyResult: ScanServiceResult?
  var previewError: Error?
  private(set) var applyCallCount = 0
  private(set) var appliedIdentities: [Set<FileIdentity>] = []
  private(set) var pauseCallCount = 0
  private(set) var resumeCallCount = 0
  private(set) var rulesChangedCallCount = 0
  private(set) var shutdownCallCount = 0
  private(set) var lastRoots: [URL: Set<FileIdentity>] = [:]

  func start(roots: [URL: Set<FileIdentity>]) async { lastRoots = roots }
  func updateRoots(_ roots: [URL: Set<FileIdentity>]) async { lastRoots = roots }
  func preview(root: URL) async throws -> ScanServiceResult {
    if let previewError { throw previewError }
    return previewResult
  }
  func apply(root: URL, identities: Set<FileIdentity>) async throws -> ScanServiceResult {
    applyCallCount += 1
    appliedIdentities.append(identities)
    return applyResult ?? previewResult
  }
  func pause() async { pauseCallCount += 1 }
  func resume() async { resumeCallCount += 1 }
  func rulesDidChange() async { rulesChangedCallCount += 1 }
  func shutdown() async { shutdownCallCount += 1 }
}

@MainActor
private final class DirectAppScanController: AppScanControlling {
  private let service: NormalizationScanService

  init(service: NormalizationScanService) {
    self.service = service
  }

  func start(roots: [URL: Set<FileIdentity>]) async {}
  func updateRoots(_ roots: [URL: Set<FileIdentity>]) async {}

  func preview(root: URL) async throws -> ScanServiceResult {
    try await service.scan(ScanRequest(root: root, scope: .manualPreview))
  }

  func apply(root: URL, identities: Set<FileIdentity>) async throws -> ScanServiceResult {
    try await service.scan(ScanRequest(root: root, scope: .manualApply(identities)))
  }

  func pause() async {}
  func resume() async {}
  func rulesDidChange() async {}
  func shutdown() async {}
}

@MainActor
private final class HistoryBackedDataService: AppDataServicing {
  private let folder: AppFolder
  private let ruleStore: StabilityRuleStore
  private let history: HistoryStore

  init(root: URL, ruleStore: StabilityRuleStore, history: HistoryStore) {
    folder = AppFolder(
      id: UUID(),
      url: root,
      displayName: root.lastPathComponent,
      isEnabled: true,
      status: .available
    )
    self.ruleStore = ruleStore
    self.history = history
  }

  func loadFolders() async throws -> [AppFolder] { [folder] }
  func loadRules() async throws -> [StabilityExclusionRule] { try await ruleStore.allRules() }
  func loadHistory() async throws -> [HistoryEvent] { try await history.load().events }

  func addFolder(url: URL, mode: WatchedFolderNormalizationMode) async throws -> AppFolder {
    folder
  }

  func removeFolder(id: UUID) async throws {}
  func setFolderEnabled(id: UUID, enabled: Bool) async throws {}
  func reselectFolder(id: UUID, url: URL) async throws {}

  func addRule(kind: StabilityRuleKind, pattern: String) async throws -> StabilityExclusionRule {
    try await ruleStore.add(kind: kind, pattern: pattern)
  }

  func removeRule(id: String) async throws { try await ruleStore.remove(id: id) }
  func shutdown() async {}
}

private final class ManualScanFixture {
  let container: URL
  let root: URL
  let state: URL
  let ruleStore: StabilityRuleStore
  let history: HistoryStore

  init() throws {
    container = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    root = container.appendingPathComponent("watched", isDirectory: true)
    state = container.appendingPathComponent("state", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
    ruleStore = StabilityRuleStore(fileURL: state.appendingPathComponent("rules.json"))
    history = HistoryStore(fileURL: state.appendingPathComponent("history.jsonl"))
  }

  func makeService() -> NormalizationScanService {
    NormalizationScanService(
      ruleStore: ruleStore,
      tracker: StabilityTracker(quietPeriod: 30),
      engine: SafeRenameEngine(
        journal: RecoveryJournal(directory: state.appendingPathComponent("recovery"))
      ),
      history: history,
      excludedRoots: [state]
    )
  }

  func remove() { try? FileManager.default.removeItem(at: container) }

  func rawNames() throws -> [String] {
    try root.withUnsafeFileSystemRepresentation { path in
      guard let path, let stream = Darwin.opendir(path) else { throw POSIXError(.EIO) }
      defer { Darwin.closedir(stream) }
      var names: [String] = []
      while let entry = Darwin.readdir(stream) {
        let length = Int(entry.pointee.d_namlen)
        let bytes = withUnsafeBytes(of: &entry.pointee.d_name) { Array($0.prefix(length)) }
        let name = String(decoding: bytes, as: UTF8.self)
        if name != "." && name != ".." { names.append(name) }
      }
      return names
    }
  }
}

extension [String] {
  fileprivate func containsRawBytes(_ expected: String) -> Bool {
    let expectedBytes = [UInt8](expected.utf8)
    return contains { [UInt8]($0.utf8) == expectedBytes }
  }
}

@MainActor
private final class FakePreferences: AppPreferencesStoring {
  var isPaused = false
  var language: MoaIMFLanguage = .system
  var isLaunchHintHidden = false
}

@MainActor
private final class FakeLoginService: LoginItemService {
  var status: LoginItemServiceStatus = .disabled
  func register() throws { status = .enabled }
  func unregister() throws { status = .disabled }
  func openSystemSettings() {}
}

@MainActor
private final class FakeNotificationService: NotificationCenterService {
  func requestAuthorization() async throws -> Bool { true }
  func deliver(_ notification: SystemNotification) async throws {}
}

private func folder(
  id: UUID = UUID(),
  status: WatchedFolderStatus = .available
) -> AppFolder {
  AppFolder(
    id: id,
    url: URL(fileURLWithPath: "/tmp/Downloads"),
    displayName: "Downloads",
    isEnabled: true,
    status: status
  )
}

private func candidate(name: String) -> RenameCandidate {
  RenameCandidate(
    identity: FileIdentity(volume: "volume", resource: UUID().uuidString),
    source: URL(fileURLWithPath: "/tmp/Downloads/\(name)"),
    targetName: "한글.txt"
  )
}

private func collision() -> NormalizationCollision {
  NormalizationCollision(
    parent: URL(fileURLWithPath: "/tmp/Downloads"),
    normalizedKey: "한글.txt",
    rawNames: ["한글.txt", "한글.txt"]
  )
}

private enum ScanTestError: LocalizedError {
  case failed

  var errorDescription: String? { "The scan failed in the test." }
}
