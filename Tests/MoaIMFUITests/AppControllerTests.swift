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
  var didTerminate = false
  lazy var controller = AppController(
    dataService: data,
    scanController: scanner,
    preferences: preferences,
    loginItemManager: LoginItemManager(service: FakeLoginService()),
    notifier: SystemNotifier(center: FakeNotificationService()),
    terminate: { [weak self] in self?.didTerminate = true }
  )
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
  private(set) var applyCallCount = 0
  private(set) var pauseCallCount = 0
  private(set) var resumeCallCount = 0
  private(set) var rulesChangedCallCount = 0
  private(set) var shutdownCallCount = 0
  private(set) var lastRoots: [URL: Set<FileIdentity>] = [:]

  func start(roots: [URL: Set<FileIdentity>]) async { lastRoots = roots }
  func updateRoots(_ roots: [URL: Set<FileIdentity>]) async { lastRoots = roots }
  func preview(root: URL) async throws -> ScanServiceResult { previewResult }
  func apply(root: URL, identities: Set<FileIdentity>) async throws -> ScanServiceResult {
    applyCallCount += 1
    return previewResult
  }
  func pause() async { pauseCallCount += 1 }
  func resume() async { resumeCallCount += 1 }
  func rulesDidChange() async { rulesChangedCallCount += 1 }
  func shutdown() async { shutdownCallCount += 1 }
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
