import AppKit
import MoaIMFCore
import SwiftUI
import XCTest

@testable import MoaIMFUI

final class VisualRenderingTests: XCTestCase {
  @MainActor
  func testFirstRunSettingsRendersToPNG() throws {
    let controller = MoaIMFEnvironment.makeController {}
    try render(
      SettingsView(controller: controller),
      named: "moaimf-settings-first-run.png",
      size: NSSize(width: 720, height: 520)
    )
  }

  @MainActor
  func testConfiguredSurfacesRenderToPNG() async throws {
    let data = SnapshotDataService()
    let scanController = SnapshotScanController()
    let controller = AppController(
      dataService: data,
      scanController: scanController,
      preferences: SnapshotPreferences(),
      terminate: {}
    )
    await controller.load()
    await controller.scanFolder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)

    let updateMenuSize = NSSize(width: 520, height: 760)
    let idleController = makeUpdateController(
      service: SnapshotUpdateService(checkResult: .current(latestVersion: "0.1.1"))
    )
    try render(
      MenuBarView(controller: idleController),
      named: "moaimf-menu-update-idle.png",
      size: updateMenuSize
    )

    let checkingController = makeUpdateController(
      service: SnapshotUpdateService(
        checkResult: .current(latestVersion: "0.1.1"),
        checkDelayNanoseconds: 500_000_000
      )
    )
    let checkingTask = Task { await checkingController.checkForUpdates() }
    try await Task.sleep(nanoseconds: 50_000_000)
    try render(
      MenuBarView(controller: checkingController),
      named: "moaimf-menu-update-checking.png",
      size: updateMenuSize
    )
    checkingTask.cancel()
    _ = await checkingTask.value

    let currentController = makeUpdateController(
      service: SnapshotUpdateService(checkResult: .current(latestVersion: "0.1.1"))
    )
    await currentController.checkForUpdates()
    try render(
      MenuBarView(controller: currentController),
      named: "moaimf-menu-update-current.png",
      size: updateMenuSize
    )

    let updateController = makeUpdateController(service: SnapshotUpdateService())
    await updateController.checkForUpdates(manually: false)
    try render(
      MenuBarView(controller: updateController),
      named: "moaimf-menu-update.png",
      size: updateMenuSize
    )

    let downloadingController = makeUpdateController(
      service: SnapshotUpdateService(downloadDelayNanoseconds: 500_000_000)
    )
    await downloadingController.checkForUpdates()
    let downloadingTask = Task { await downloadingController.downloadAvailableUpdate() }
    try await Task.sleep(nanoseconds: 50_000_000)
    try render(
      MenuBarView(controller: downloadingController),
      named: "moaimf-menu-update-downloading.png",
      size: updateMenuSize
    )
    downloadingTask.cancel()
    _ = await downloadingTask.value

    let downloadedController = makeUpdateController(service: SnapshotUpdateService())
    await downloadedController.checkForUpdates()
    await downloadedController.downloadAvailableUpdate()
    try render(
      MenuBarView(controller: downloadedController),
      named: "moaimf-menu-update-downloaded.png",
      size: updateMenuSize
    )

    let frenchLanguage = LanguageManager(preferences: SnapshotPreferences())
    frenchLanguage.setLanguage(.french)
    let longLabelController = makeUpdateController(
      service: SnapshotUpdateService(checkResult: .available(SnapshotUpdateService.longUpdate)),
      languageManager: frenchLanguage
    )
    await longLabelController.checkForUpdates()
    try render(
      MenuBarView(controller: longLabelController),
      named: "moaimf-menu-update-long-locale.png",
      size: updateMenuSize
    )
    MoaIMFLocalization.setLanguage(.system)

    try render(
      SettingsView(controller: controller),
      named: "moaimf-settings-folders.png",
      size: NSSize(width: 800, height: 620)
    )
    try render(
      StabilityRulesView(controller: controller),
      named: "moaimf-settings-rules.png",
      size: NSSize(width: 700, height: 480)
    )
    try render(
      HistoryView(controller: controller),
      named: "moaimf-history.png",
      size: NSSize(width: 720, height: 480)
    )
    try render(
      HistoryView(controller: controller),
      named: "moaimf-history-minimum.png",
      size: HistoryView.minimumSize
    )
    try render(
      HistoryView(controller: controller, searchText: "한글"),
      named: "moaimf-history-search.png",
      size: NSSize(width: 720, height: 480)
    )
    try render(
      AboutView(
        info: AboutAppInfo(
          appName: "MoaIMF",
          version: "0.1.1",
          build: "2",
          copyright: "Copyright © 2026 copylawbot"
        )
      ),
      named: "moaimf-about.png",
      size: NSSize(width: 460, height: 320)
    )
    try render(
      LaunchHintView(),
      named: "moaimf-launch-hint.png",
      size: LaunchHintView.preferredSize
    )
    let report = try XCTUnwrap(
      controller.folderScanReports[UUID(uuidString: "00000000-0000-0000-0000-000000000001")!]
    )
    try render(
      FolderScanReportView(report: report).padding(20),
      named: "moaimf-folder-scan-report.png",
      size: NSSize(width: 720, height: 180)
    )
    let changedSource = URL(fileURLWithPath: "/Users/example/Downloads/한글-보고서.txt")
    let changedTarget = URL(fileURLWithPath: "/Users/example/Downloads/한글-보고서.txt")
    let changedOutcome = RenameOutcome(
      identity: FileIdentity(volume: "snapshot", resource: "changed"),
      source: changedSource,
      target: changedTarget,
      kind: .renamed,
      reason: nil
    )
    let longChangedSource = URL(
      fileURLWithPath: "/Users/example/Downloads/한글-보고서-2026년-8월-최종검토본.txt"
    )
    let longChangedTarget = URL(
      fileURLWithPath: "/Users/example/Downloads/한글-보고서-2026년-8월-최종검토본.txt"
    )
    let longChangedOutcome = RenameOutcome(
      identity: FileIdentity(volume: "snapshot", resource: "long-changed"),
      source: longChangedSource,
      target: longChangedTarget,
      kind: .renamed,
      reason: nil
    )
    let scanResult = ScanResultSummary(
      reports: [
        FolderScanReport(
          root: report.root,
          scannedAt: Date(),
          result: ScanServiceResult(
            summary: ScanContentSummary(
              totalEntryCount: 12,
              nfcEntryCount: 9,
              nonNFCEntryCount: 3
            ),
            plan: NormalizationPlan(
              candidates: [
                RenameCandidate(
                  identity: changedOutcome.identity,
                  source: changedSource,
                  targetName: changedTarget.lastPathComponent
                ),
                RenameCandidate(
                  identity: longChangedOutcome.identity,
                  source: longChangedSource,
                  targetName: longChangedTarget.lastPathComponent
                ),
              ],
              collisions: [
                NormalizationCollision(
                  parent: report.root,
                  normalizedKey: "충돌.txt",
                  rawNames: ["충돌.txt", "충돌.txt"]
                )
              ]
            ),
            outcomes: [changedOutcome, longChangedOutcome],
            deferredIdentities: [FileIdentity(volume: "snapshot", resource: "deferred")]
          )
        )
      ]
    )
    try render(
      ScanResultView(summary: scanResult),
      named: "moaimf-scan-result.png",
      size: ScanResultView.preferredSize
    )
    try render(
      UpdateCurrentView(),
      named: "moaimf-update-current.png",
      size: UpdateCurrentView.preferredSize
    )
    try render(
      UpdateFailureView(message: "The update server returned HTTP status 503."),
      named: "moaimf-update-failure.png",
      size: UpdateFailureView.preferredSize
    )
    try render(
      UpdateAvailableView(
        update: AppUpdate(
          version: "0.1.2",
          tagName: "v0.1.2",
          releaseURL: URL(string: "https://example.com/release")!,
          assetName: "MoaIMF-0.1.2.dmg",
          downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!,
          releaseNotes: """
            # MoaIMF v0.1.2

            - 수동 업데이트 확인 결과를 언제나 명확하게 표시합니다.
            - GitHub 릴리즈 노트 전체 내용을 줄바꿈과 함께 보여줍니다.
            - 다운로드 버튼을 메뉴에서 계속 사용할 수 있습니다.
            """
        )
      ),
      named: "moaimf-update-available.png",
      size: UpdateAvailableView.preferredSize
    )
  }

  @MainActor
  private func render<Content: View>(_ view: Content, named name: String, size: NSSize) throws {
    let hostingView = NSHostingView(rootView: view)
    hostingView.appearance = NSAppearance(named: .aqua)
    hostingView.wantsLayer = true
    hostingView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    hostingView.frame = NSRect(origin: .zero, size: size)
    hostingView.layoutSubtreeIfNeeded()
    let representation = try XCTUnwrap(
      hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
    hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
    let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
    let output = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try png.write(to: output, options: .atomic)

    XCTAssertGreaterThan(png.count, 1_000)
  }

  @MainActor
  private func makeUpdateController(
    service: any AppUpdateServicing,
    languageManager: LanguageManager? = nil
  ) -> AppController {
    AppController(
      dataService: SnapshotDataService(),
      scanController: SnapshotScanController(),
      preferences: SnapshotPreferences(),
      languageManager: languageManager,
      updateService: service,
      revealDownloadedUpdate: { _ in },
      terminate: {}
    )
  }
}

@MainActor
private final class SnapshotDataService: AppDataServicing {
  private let root = URL(
    fileURLWithPath: "/Users/example/Downloads/아주 긴 한국어 프로젝트 폴더/최종 산출물",
    isDirectory: true
  )

  func loadFolders() async throws -> [AppFolder] {
    [
      AppFolder(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        url: root,
        displayName: "최종 산출물",
        isEnabled: true,
        status: .available,
        lastScan: Date(),
        collisionCount: 0
      ),
      AppFolder(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
        url: URL(fileURLWithPath: "/Volumes/외장 디스크/공유 자료"),
        displayName: "공유 자료",
        isEnabled: true,
        status: .disconnected,
        collisionCount: 2
      ),
    ]
  }

  func loadRules() async throws -> [StabilityExclusionRule] {
    StabilityExclusionMatcher.builtInRules + [
      StabilityExclusionRule(
        id: "snapshot.user",
        kind: .glob,
        pattern: "*.download-진행중-아주긴패턴-*",
        source: .user
      )
    ]
  }

  func loadHistory() async throws -> [HistoryEvent] {
    [
      HistoryEvent(
        timestamp: Date(),
        kind: .renamed,
        rootIdentifier: root.path,
        previousURL: root.appendingPathComponent("한글.txt"),
        resultingURL: root.appendingPathComponent("한글.txt"),
        reason: "renamed"
      ),
      HistoryEvent(
        timestamp: Date().addingTimeInterval(-60),
        kind: .collision,
        rootIdentifier: root.path,
        previousURL: root,
        resultingURL: nil,
        reason: "한글.txt 이름 충돌"
      ),
    ]
  }

  func addFolder(
    url: URL,
    mode: WatchedFolderNormalizationMode
  ) async throws -> AppFolder { try await loadFolders()[0] }
  func removeFolder(id: UUID) async throws {}
  func setFolderEnabled(id: UUID, enabled: Bool) async throws {}
  func reselectFolder(id: UUID, url: URL) async throws {}
  func addRule(kind: StabilityRuleKind, pattern: String) async throws -> StabilityExclusionRule {
    StabilityExclusionRule(id: "new", kind: kind, pattern: pattern, source: .user)
  }
  func removeRule(id: String) async throws {}
  func shutdown() async {}
}

@MainActor
private final class SnapshotScanController: AppScanControlling {
  func start(roots: [URL: Set<FileIdentity>]) async {}
  func updateRoots(_ roots: [URL: Set<FileIdentity>]) async {}
  func preview(root: URL) async throws -> ScanServiceResult {
    ScanServiceResult(
      summary: ScanContentSummary(totalEntryCount: 12, nfcEntryCount: 9, nonNFCEntryCount: 3),
      plan: NormalizationPlan(
        candidates: [
          RenameCandidate(
            identity: FileIdentity(volume: "snapshot", resource: "1"),
            source: root.appendingPathComponent("한글-보고서.txt"),
            targetName: "한글-보고서.txt"
          ),
          RenameCandidate(
            identity: FileIdentity(volume: "snapshot", resource: "2"),
            source: root.appendingPathComponent("사진.zip"),
            targetName: "사진.zip"
          ),
        ],
        collisions: []
      ),
      deferredIdentities: [FileIdentity(volume: "snapshot", resource: "partial")]
    )
  }
  func apply(root: URL, identities: Set<FileIdentity>) async throws -> ScanServiceResult {
    ScanServiceResult()
  }
  func pause() async {}
  func resume() async {}
  func rulesDidChange() async {}
  func shutdown() async {}
}

@MainActor
private final class SnapshotUpdateService: AppUpdateServicing {
  static let longUpdate = AppUpdate(
    version: "123.456.789",
    tagName: "v123.456.789",
    releaseURL: URL(string: "https://example.com/release")!,
    assetName: "MoaIMF-123.456.789.dmg",
    downloadURL: URL(string: "https://example.com/MoaIMF-123.456.789.dmg")!
  )

  let checkResult: AppUpdateCheckResult
  let checkDelayNanoseconds: UInt64
  let downloadDelayNanoseconds: UInt64

  init(
    checkResult: AppUpdateCheckResult = .available(
      AppUpdate(
        version: "0.1.2",
        tagName: "v0.1.2",
        releaseURL: URL(string: "https://example.com/release")!,
        assetName: "MoaIMF-0.1.2.dmg",
        downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
      )
    ),
    checkDelayNanoseconds: UInt64 = 0,
    downloadDelayNanoseconds: UInt64 = 0
  ) {
    self.checkResult = checkResult
    self.checkDelayNanoseconds = checkDelayNanoseconds
    self.downloadDelayNanoseconds = downloadDelayNanoseconds
  }

  func check(currentVersion: String) async throws -> AppUpdateCheckResult {
    if checkDelayNanoseconds > 0 {
      try await Task.sleep(nanoseconds: checkDelayNanoseconds)
    }
    return checkResult
  }

  func download(_ update: AppUpdate) async throws -> URL {
    if downloadDelayNanoseconds > 0 {
      try await Task.sleep(nanoseconds: downloadDelayNanoseconds)
    }
    return FileManager.default.temporaryDirectory.appendingPathComponent(update.assetName)
  }
}

@MainActor
private final class SnapshotPreferences: AppPreferencesStoring {
  var isPaused = false
  var language: MoaIMFLanguage = .system
  var isLaunchHintHidden = false
}
