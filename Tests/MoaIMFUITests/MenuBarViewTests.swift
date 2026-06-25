import AppKit
import MoaIMFCore
import SwiftUI
import XCTest

@testable import MoaIMFUI

final class MenuBarViewTests: XCTestCase {
  @MainActor
  func testMenuBarViewCanBeConstructed() {
    let controller = MoaIMFEnvironment.makeController {}
    _ = MenuBarView(controller: controller)
  }

  @MainActor
  func testWindowManagerPresentsSettingsWindow() {
    let controller = MoaIMFEnvironment.makeController {}
    let manager = AppWindowManager()

    manager.showSettings(controller: controller)

    XCTAssertTrue(manager.isSettingsVisible)
    manager.closeAll()
  }

  @MainActor
  func testWindowManagerPresentsAboutWindow() {
    let manager = AppWindowManager()

    manager.showAbout()

    XCTAssertTrue(manager.isAboutVisible)
    manager.closeAll()
  }

  @MainActor
  func testWindowManagerPresentsLaunchHintWhenPreferenceAllowsIt() {
    let preferences = MenuBarPreferences()
    let manager = AppWindowManager()

    manager.showLaunchHintIfNeeded(preferences: preferences)

    XCTAssertTrue(manager.isLaunchHintVisible)
    manager.closeAll()
  }

  @MainActor
  func testWindowManagerSkipsLaunchHintWhenHidden() {
    let preferences = MenuBarPreferences()
    preferences.isLaunchHintHidden = true
    let manager = AppWindowManager()

    manager.showLaunchHintIfNeeded(preferences: preferences)

    XCTAssertFalse(manager.isLaunchHintVisible)
    manager.closeAll()
  }

  @MainActor
  func testWindowManagerEnforcesHistoryMinimumWindowSize() throws {
    let controller = MoaIMFEnvironment.makeController {}
    let manager = AppWindowManager()

    manager.showHistory(controller: controller)

    let contentMinimumSize = try XCTUnwrap(manager.historyContentMinimumSize)
    let frameMinimumSize = try XCTUnwrap(manager.historyFrameMinimumSize)
    let frameMaximumSize = try XCTUnwrap(manager.historyFrameMaximumSize)
    XCTAssertEqual(contentMinimumSize, HistoryView.minimumSize)
    XCTAssertGreaterThanOrEqual(frameMinimumSize.width, HistoryView.minimumSize.width)
    XCTAssertGreaterThanOrEqual(frameMinimumSize.height, HistoryView.minimumSize.height)
    XCTAssertEqual(frameMaximumSize, frameMinimumSize)
    XCTAssertFalse(manager.isHistoryResizable)
    manager.closeAll()
  }

  @MainActor
  func testAboutWindowSurvivesDisplayCycleAfterPresentation() {
    let manager = AppWindowManager()

    manager.showAbout()
    RunLoop.main.run(until: Date().addingTimeInterval(0.2))

    XCTAssertTrue(manager.isAboutVisible)
    manager.closeAll()
  }

  func testAboutInfoFormatsVersionAndBuild() {
    let info = AboutAppInfo(
      appName: "MoaIMF",
      version: "0.1.0",
      build: "1",
      copyright: "Copyright © 2026 copylawbot"
    )

    XCTAssertTrue(info.versionText.contains("0.1.0"))
    XCTAssertTrue(info.versionText.contains("(1)"))
  }

  @MainActor
  func testLoginItemStatusViewRerendersAfterLanguageChange() throws {
    let preferences = MenuBarPreferences()
    let languageManager = LanguageManager(preferences: preferences)
    languageManager.setLanguage(.english)
    defer { MoaIMFLocalization.setLanguage(.system) }

    let hostingView = NSHostingView(
      rootView: LoginItemStatusView(state: .enabled, languageManager: languageManager)
    )
    hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 60)
    hostingView.layoutSubtreeIfNeeded()
    let englishPNG = try snapshotPNG(of: hostingView)

    languageManager.setLanguage(.korean)
    hostingView.layoutSubtreeIfNeeded()
    let koreanPNG = try snapshotPNG(of: hostingView)

    XCTAssertNotEqual(
      englishPNG,
      koreanPNG,
      "Login item status should visually re-render with the newly selected language."
    )
  }

  @MainActor
  func testSettingsViewRerendersAfterLanguageChange() async throws {
    let preferences = MenuBarPreferences()
    let languageManager = LanguageManager(preferences: preferences)
    languageManager.setLanguage(.english)
    defer { MoaIMFLocalization.setLanguage(.system) }
    let controller = AppController(
      dataService: SettingsLanguageDataService(),
      scanController: SettingsLanguageScanController(),
      preferences: preferences,
      languageManager: languageManager,
      terminate: {}
    )
    await controller.load()
    let hostingView = NSHostingView(rootView: SettingsView(controller: controller))
    hostingView.frame = NSRect(x: 0, y: 0, width: 720, height: 520)
    hostingView.layoutSubtreeIfNeeded()
    let englishPNG = try snapshotPNGWithoutForcingInvalidation(of: hostingView)

    languageManager.setLanguage(.korean)
    hostingView.layoutSubtreeIfNeeded()
    let koreanPNG = try snapshotPNGWithoutForcingInvalidation(of: hostingView)

    XCTAssertNotEqual(
      englishPNG,
      koreanPNG,
      "Settings should visually re-render with the newly selected language."
    )
  }

  @MainActor
  private func snapshotPNG(of view: NSView) throws -> Data {
    view.needsLayout = true
    view.layoutSubtreeIfNeeded()
    return try snapshotPNGWithoutForcingInvalidation(of: view)
  }

  @MainActor
  private func snapshotPNGWithoutForcingInvalidation(of view: NSView) throws -> Data {
    let representation = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
    view.cacheDisplay(in: view.bounds, to: representation)
    return try XCTUnwrap(representation.representation(using: .png, properties: [:]))
  }
}

@MainActor
private final class MenuBarPreferences: AppPreferencesStoring {
  var isPaused = false
  var language: MoaIMFLanguage = .system
  var isLaunchHintHidden = false
}

@MainActor
private final class SettingsLanguageDataService: AppDataServicing {
  private let root = URL(fileURLWithPath: "/Users/example/Downloads", isDirectory: true)

  func loadFolders() async throws -> [AppFolder] {
    [
      AppFolder(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000010") ?? UUID(),
        url: root,
        displayName: "Downloads",
        isEnabled: true,
        status: .available,
        lastScan: Date(timeIntervalSince1970: 0)
      )
    ]
  }

  func loadRules() async throws -> [StabilityExclusionRule] {
    StabilityExclusionMatcher.builtInRules
  }

  func loadHistory() async throws -> [HistoryEvent] { [] }

  func addFolder(url: URL, mode: WatchedFolderNormalizationMode) async throws -> AppFolder {
    try await loadFolders()[0]
  }

  func removeFolder(id: UUID) async throws {}
  func setFolderEnabled(id: UUID, enabled: Bool) async throws {}
  func reselectFolder(id: UUID, url: URL) async throws {}

  func addRule(kind: StabilityRuleKind, pattern: String) async throws -> StabilityExclusionRule {
    StabilityExclusionRule(id: "test", kind: kind, pattern: pattern, source: .user)
  }

  func removeRule(id: String) async throws {}
  func shutdown() async {}
}

@MainActor
private final class SettingsLanguageScanController: AppScanControlling {
  func start(roots: [URL: Set<FileIdentity>]) async {}
  func updateRoots(_ roots: [URL: Set<FileIdentity>]) async {}
  func preview(root: URL) async throws -> ScanServiceResult { ScanServiceResult() }
  func apply(root: URL, identities: Set<FileIdentity>) async throws -> ScanServiceResult {
    ScanServiceResult()
  }
  func pause() async {}
  func resume() async {}
  func rulesDidChange() async {}
  func shutdown() async {}
}
