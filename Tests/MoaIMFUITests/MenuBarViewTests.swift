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
  func testUpdateMenuItemHasIndependentCheckAndDownloadButtons() {
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    var checkCount = 0
    var downloadCount = 0

    let view = UpdateMenuItemView(
      update: update,
      onCheck: { checkCount += 1 },
      onDownload: { downloadCount += 1 }
    )
    view.frame = NSRect(x: 0, y: 0, width: 320, height: 28)
    view.layoutSubtreeIfNeeded()

    let buttons = view.subviews.compactMap { $0 as? NSButton }
    XCTAssertEqual(buttons.count, 2)
    let checkButton = buttons.first { $0.identifier?.rawValue == "MoaIMF.update.check" }
    let downloadButton = buttons.first { $0.identifier?.rawValue == "MoaIMF.update.download" }
    XCTAssertNotNil(checkButton)
    XCTAssertNotNil(downloadButton)
    XCTAssertGreaterThan(downloadButton?.frame.minX ?? 0, checkButton?.frame.maxX ?? 0)

    checkButton?.performClick(nil)
    downloadButton?.performClick(nil)

    XCTAssertEqual(checkCount, 1)
    XCTAssertEqual(downloadCount, 1)
  }

  @MainActor
  func testUpdateMenuItemRowBackgroundTriggersManualCheck() {
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    var checkCount = 0
    let view = UpdateMenuItemView(
      update: update,
      onCheck: { checkCount += 1 },
      onDownload: {}
    )
    view.frame = NSRect(x: 0, y: 0, width: 320, height: 28)
    view.layoutSubtreeIfNeeded()

    guard
      let event = NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: NSPoint(x: 285, y: 14),
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
      )
    else {
      return XCTFail("Expected a mouse event for the update row")
    }
    view.mouseDown(with: event)

    XCTAssertEqual(
      checkCount,
      1,
      "Clicking the update row outside the arrow must still start a manual check."
    )
  }

  @MainActor
  func testUpdateMenuItemTitleStartsAtNativeMenuTitleColumnWhenDownloadButtonIsVisible() {
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    let view = UpdateMenuItemView(update: update, onCheck: {}, onDownload: {})
    view.frame = NSRect(x: 0, y: 0, width: 320, height: 28)
    view.layoutSubtreeIfNeeded()

    let checkButton = view.subviews
      .compactMap { $0 as? NSButton }
      .first { $0.identifier?.rawValue == "MoaIMF.update.check" }

    let referenceItem = NSMenuItem(
      title: MoaIMFLocalization.text("menu.checkForUpdates"),
      action: nil,
      keyEquivalent: ""
    )
    let referenceCell = NSMenuItemCell()
    referenceCell.menuItem = referenceItem
    referenceCell.calcSize()
    let referenceLabel = NSTextField(labelWithString: referenceItem.title)
    referenceLabel.font = NSFont.menuFont(ofSize: 0)
    let nativeTitleMinX =
      referenceCell.titleRect(forBounds: view.bounds).minX
      - referenceLabel.alignmentRectInsets.left

    XCTAssertEqual(checkButton?.frame.minX ?? -1, nativeTitleMinX, accuracy: 0.5)
  }

  @MainActor
  func testAppKitMenuKeepsAutomaticUpdateAsVisibleMenuItem() async {
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    let controller = AppController(
      dataService: MenuBarTestDataService(),
      scanController: MenuBarTestScanController(),
      preferences: MenuBarPreferences(),
      updateService: FailedDownloadUpdateService(update: update),
      terminate: {}
    )

    await controller.checkForUpdates(manually: false)
    let menuBuilder = MenuBarMenuBuilder(controller: controller)
    let updateItem = menuBuilder.menu.item(
      withTag: MenuBarMenuBuilder.updateMenuItemTag
    )

    XCTAssertNotNil(updateItem)
    XCTAssertTrue(updateItem?.submenu == nil)
    XCTAssertTrue(updateItem?.view is UpdateMenuItemView)
  }

  @MainActor
  func testAppKitMenuReservesStateColumnWhenLoginAtLaunchIsOff() async {
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    let controller = AppController(
      dataService: MenuBarTestDataService(),
      scanController: MenuBarTestScanController(),
      preferences: MenuBarPreferences(),
      loginItemManager: LoginItemManager(service: DisabledMenuBarLoginItemService()),
      updateService: FailedDownloadUpdateService(update: update),
      terminate: {}
    )

    await controller.checkForUpdates(manually: false)
    let menuBuilder = MenuBarMenuBuilder(controller: controller)
    let loginItem = menuBuilder.menu.items.first {
      $0.title == MoaIMFLocalization.text("menu.loginAtLaunch")
    }
    let updateView = menuBuilder.menu.item(
      withTag: MenuBarMenuBuilder.updateMenuItemTag
    )?.view

    XCTAssertEqual(loginItem?.state, .off)
    XCTAssertNotNil(loginItem?.offStateImage)
    XCTAssertTrue(updateView?.autoresizingMask.contains(.width) == true)
  }

  @MainActor
  func testManualUpdateCheckKeepsAutomaticDownloadMenuItem() async {
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    let controller = AppController(
      dataService: MenuBarTestDataService(),
      scanController: MenuBarTestScanController(),
      preferences: MenuBarPreferences(),
      updateService: FailedDownloadUpdateService(update: update),
      terminate: {}
    )
    let menuBuilder = MenuBarMenuBuilder(controller: controller)

    await controller.checkForUpdates(manually: false)
    menuBuilder.rebuild()
    XCTAssertTrue(
      menuBuilder.menu.item(withTag: MenuBarMenuBuilder.updateMenuItemTag)?.view
        is UpdateMenuItemView
    )

    await controller.checkForUpdates()
    menuBuilder.rebuild()

    XCTAssertTrue(
      menuBuilder.menu.item(withTag: MenuBarMenuBuilder.updateMenuItemTag)?.view
        is UpdateMenuItemView
    )
  }

  @MainActor
  func testManualUpdateCheckKeepsDownloadMenuItemWhileChecking() async {
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    let updateService = BlockingUpdateService(update: update)
    let controller = AppController(
      dataService: MenuBarTestDataService(),
      scanController: MenuBarTestScanController(),
      preferences: MenuBarPreferences(),
      updateService: updateService,
      terminate: {}
    )
    let menuBuilder = MenuBarMenuBuilder(controller: controller)

    await controller.checkForUpdates(manually: false)
    menuBuilder.rebuild()
    XCTAssertTrue(
      menuBuilder.menu.item(withTag: MenuBarMenuBuilder.updateMenuItemTag)?.view
        is UpdateMenuItemView
    )

    let checkTask = Task { await controller.checkForUpdates() }
    while !updateService.checkStarted {
      try? await Task.sleep(for: .milliseconds(1))
    }

    menuBuilder.rebuild()
    XCTAssertEqual(controller.updateCheckStatus, .checking)
    XCTAssertTrue(
      menuBuilder.menu.item(withTag: MenuBarMenuBuilder.updateMenuItemTag)?.view
        is UpdateMenuItemView
    )

    updateService.resumeCheck()
    _ = await checkTask.value
  }

  @MainActor
  func testFailedAutomaticDownloadShowsFailureStateInsteadOfDownloadRow() async {
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    let controller = AppController(
      dataService: MenuBarTestDataService(),
      scanController: MenuBarTestScanController(),
      preferences: MenuBarPreferences(),
      updateService: FailedDownloadUpdateService(update: update),
      terminate: {}
    )

    await controller.checkForUpdates(manually: false)
    XCTAssertNotNil(MenuBarView(controller: controller).automaticDownloadCandidate)

    await controller.downloadAvailableUpdate()

    let menu = MenuBarView(controller: controller)
    XCTAssertEqual(controller.updateCheckStatus, .failed)
    XCTAssertNil(menu.automaticDownloadCandidate)
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
  func testWindowManagerPresentsScanResultWindow() {
    let manager = AppWindowManager()

    manager.showScanResult(summary: ScanResultSummary(reports: []))

    XCTAssertTrue(manager.isScanResultVisible)
    manager.closeAll()
  }

  @MainActor
  func testWindowManagerPresentsUpdateWindow() {
    let manager = AppWindowManager()
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!,
      releaseNotes: "Improves update checks."
    )

    manager.showUpdateAvailable(update: update) {}

    XCTAssertTrue(manager.isUpdateVisible)
    XCTAssertGreaterThan(manager.updateFrameSize?.width ?? 0, 0)
    XCTAssertGreaterThan(manager.updateFrameSize?.height ?? 0, 0)
    manager.closeAll()
  }

  @MainActor
  func testAppKitManualCurrentUpdateCheckPresentsResultWindow() async {
    AppWindowManager.shared.closeAll()
    let controller = AppController(
      dataService: MenuBarTestDataService(),
      scanController: MenuBarTestScanController(),
      preferences: MenuBarPreferences(),
      updateService: CurrentUpdateService(),
      terminate: {}
    )
    let menuBuilder = MenuBarMenuBuilder(controller: controller)
    let updateItem = menuBuilder.menu.item(
      withTag: MenuBarMenuBuilder.updateMenuItemTag
    )

    guard let action = updateItem?.action else {
      return XCTFail("Expected an update-check action")
    }
    let sent = NSApplication.shared.sendAction(action, to: updateItem?.target, from: updateItem)
    for _ in 0..<100 where !AppWindowManager.shared.isUpdateVisible {
      try? await Task.sleep(for: .milliseconds(10))
    }

    XCTAssertTrue(sent)
    XCTAssertTrue(AppWindowManager.shared.isUpdateVisible)
    AppWindowManager.shared.closeAll()
  }

  @MainActor
  func testAppKitManualUpdateCheckFromDownloadRowPresentsResultWindow() async {
    AppWindowManager.shared.closeAll()
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    let controller = AppController(
      dataService: MenuBarTestDataService(),
      scanController: MenuBarTestScanController(),
      preferences: MenuBarPreferences(),
      updateService: FailedDownloadUpdateService(update: update),
      terminate: {}
    )
    await controller.checkForUpdates(manually: false)
    let menuBuilder = MenuBarMenuBuilder(controller: controller)
    let updateView =
      menuBuilder.menu.item(withTag: MenuBarMenuBuilder.updateMenuItemTag)?.view
      as? UpdateMenuItemView
    let checkButton = updateView?.subviews
      .compactMap { $0 as? NSButton }
      .first { $0.identifier?.rawValue == "MoaIMF.update.check" }

    checkButton?.performClick(nil)
    for _ in 0..<100 where !AppWindowManager.shared.isUpdateVisible {
      try? await Task.sleep(for: .milliseconds(10))
    }

    XCTAssertNotNil(checkButton)
    XCTAssertTrue(
      AppWindowManager.shared.isUpdateVisible,
      "Clicking update check in the download row must show the result window."
    )
    AppWindowManager.shared.closeAll()
  }

  @MainActor
  func testManualUpdateCheckCanBeRepeatedAfterAvailablePopupDismissed() async {
    AppWindowManager.shared.closeAll()
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )
    let updateService = FailedDownloadUpdateService(update: update)
    let controller = AppController(
      dataService: MenuBarTestDataService(),
      scanController: MenuBarTestScanController(),
      preferences: MenuBarPreferences(),
      updateService: updateService,
      terminate: {}
    )
    let menuBuilder = MenuBarMenuBuilder(controller: controller)
    let firstItem = menuBuilder.menu.item(withTag: MenuBarMenuBuilder.updateMenuItemTag)

    guard let action = firstItem?.action else {
      return XCTFail("Expected an update-check action")
    }
    _ = NSApplication.shared.sendAction(action, to: firstItem?.target, from: firstItem)
    for _ in 0..<100 where !AppWindowManager.shared.isUpdateVisible {
      try? await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertEqual(updateService.checkCount, 1)
    XCTAssertTrue(AppWindowManager.shared.isUpdateVisible)

    AppWindowManager.shared.closeAll()
    menuBuilder.rebuild()
    let updateView =
      menuBuilder.menu.item(withTag: MenuBarMenuBuilder.updateMenuItemTag)?.view
      as? UpdateMenuItemView
    guard let updateView, let event = updateRowMouseEvent() else {
      return XCTFail("Expected the available-update row and a mouse event")
    }
    XCTAssertNotNil(
      updateView.subviews
        .compactMap { $0 as? NSButton }
        .first { $0.identifier?.rawValue == "MoaIMF.update.download" }
    )

    updateView.mouseDown(with: event)
    for _ in 0..<100 where updateService.checkCount < 2 {
      try? await Task.sleep(for: .milliseconds(10))
    }
    for _ in 0..<100 where !AppWindowManager.shared.isUpdateVisible {
      try? await Task.sleep(for: .milliseconds(10))
    }

    XCTAssertEqual(updateService.checkCount, 2)
    XCTAssertTrue(AppWindowManager.shared.isUpdateVisible)
    menuBuilder.rebuild()
    let secondUpdateView =
      menuBuilder.menu.item(withTag: MenuBarMenuBuilder.updateMenuItemTag)?.view
      as? UpdateMenuItemView
    XCTAssertNotNil(
      secondUpdateView?.subviews
        .compactMap { $0 as? NSButton }
        .first { $0.identifier?.rawValue == "MoaIMF.update.download" }
    )
    AppWindowManager.shared.closeAll()
  }

  @MainActor
  func testAppKitManualUpdateCheckFailurePresentsResultWindow() async {
    AppWindowManager.shared.closeAll()
    let controller = AppController(
      dataService: MenuBarTestDataService(),
      scanController: MenuBarTestScanController(),
      preferences: MenuBarPreferences(),
      updateService: FailedCheckUpdateService(),
      terminate: {}
    )
    let menuBuilder = MenuBarMenuBuilder(controller: controller)
    let updateItem = menuBuilder.menu.item(
      withTag: MenuBarMenuBuilder.updateMenuItemTag
    )

    guard let action = updateItem?.action else {
      return XCTFail("Expected an update-check action")
    }
    let sent = NSApplication.shared.sendAction(action, to: updateItem?.target, from: updateItem)
    for _ in 0..<100 where !AppWindowManager.shared.isUpdateVisible {
      try? await Task.sleep(for: .milliseconds(10))
    }

    XCTAssertTrue(sent)
    XCTAssertTrue(
      AppWindowManager.shared.isUpdateVisible,
      "A failed manual update check must show an explanatory result window."
    )
    AppWindowManager.shared.closeAll()
  }

  @MainActor
  func testFailurePopupConfirmationRetriesUpdateCheck() async {
    AppWindowManager.shared.closeAll()
    let updateService = RetryUpdateService()
    let controller = AppController(
      dataService: MenuBarTestDataService(),
      scanController: MenuBarTestScanController(),
      preferences: MenuBarPreferences(),
      updateService: updateService,
      terminate: {}
    )
    let menuBuilder = MenuBarMenuBuilder(controller: controller)
    let updateItem = menuBuilder.menu.item(
      withTag: MenuBarMenuBuilder.updateMenuItemTag
    )

    guard let action = updateItem?.action else {
      return XCTFail("Expected an update-check action")
    }
    _ = NSApplication.shared.sendAction(action, to: updateItem?.target, from: updateItem)
    for _ in 0..<100 where !AppWindowManager.shared.isUpdateVisible {
      try? await Task.sleep(for: .milliseconds(10))
    }

    XCTAssertEqual(updateService.checkCount, 1)
    let retryAction = AppWindowManager.shared.updateFailureRetryAction
    XCTAssertNotNil(retryAction)

    retryAction?()
    for _ in 0..<100 where updateService.checkCount < 2 {
      try? await Task.sleep(for: .milliseconds(10))
    }
    for _ in 0..<100 where !AppWindowManager.shared.isUpdateVisible {
      try? await Task.sleep(for: .milliseconds(10))
    }

    XCTAssertEqual(
      updateService.checkCount,
      2,
      "Confirming an update-check failure must start a new update check."
    )
    XCTAssertEqual(controller.updateCheckStatus, .current)
    XCTAssertEqual(
      AppWindowManager.shared.updateWindowTitle,
      MoaIMFLocalization.text("updateCurrent.title")
    )
    AppWindowManager.shared.closeAll()
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
  func testDismissingLaunchHintHidesWindowWithoutClosingIt() {
    let preferences = MenuBarPreferences()
    let manager = AppWindowManager()

    manager.showLaunchHintIfNeeded(preferences: preferences)
    XCTAssertTrue(manager.isLaunchHintVisible)

    manager.dismissLaunchHint(dontShowAgain: false, preferences: preferences)

    XCTAssertFalse(manager.isLaunchHintVisible)
    XCTAssertTrue(manager.hasLaunchHintWindow)
    XCTAssertFalse(preferences.isLaunchHintHidden)
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
      version: "0.1.1",
      build: "2",
      copyright: "Copyright © 2026 copylawbot"
    )

    XCTAssertTrue(info.versionText.contains("0.1.1"))
    XCTAssertTrue(info.versionText.contains("(2)"))
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

  @MainActor
  private func updateRowMouseEvent() -> NSEvent? {
    NSEvent.mouseEvent(
      with: .leftMouseDown,
      location: NSPoint(x: 285, y: 14),
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      eventNumber: 0,
      clickCount: 1,
      pressure: 1
    )
  }

}

@MainActor
private final class MenuBarPreferences: AppPreferencesStoring {
  var isPaused = false
  var language: MoaIMFLanguage = .system
  var isLaunchHintHidden = false
}

@MainActor
private final class DisabledMenuBarLoginItemService: LoginItemService {
  let status: LoginItemServiceStatus = .disabled

  func register() throws {}
  func unregister() throws {}
  func openSystemSettings() {}
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

@MainActor
private final class FailedDownloadUpdateService: AppUpdateServicing {
  private let update: AppUpdate
  private(set) var checkCount = 0

  init(update: AppUpdate) {
    self.update = update
  }

  func check(currentVersion: String) async throws -> AppUpdateCheckResult {
    checkCount += 1
    return .available(update)
  }

  func download(_ update: AppUpdate) async throws -> URL {
    throw AppUpdateError.httpStatus(500)
  }
}

@MainActor
private final class CurrentUpdateService: AppUpdateServicing {
  func check(currentVersion: String) async throws -> AppUpdateCheckResult {
    .current(latestVersion: currentVersion)
  }

  func download(_ update: AppUpdate) async throws -> URL {
    throw AppUpdateError.noDownloadAsset
  }
}

@MainActor
private final class FailedCheckUpdateService: AppUpdateServicing {
  func check(currentVersion: String) async throws -> AppUpdateCheckResult {
    throw AppUpdateError.httpStatus(503)
  }

  func download(_ update: AppUpdate) async throws -> URL {
    throw AppUpdateError.noDownloadAsset
  }
}

@MainActor
private final class RetryUpdateService: AppUpdateServicing {
  private(set) var checkCount = 0

  func check(currentVersion: String) async throws -> AppUpdateCheckResult {
    checkCount += 1
    if checkCount == 1 {
      throw AppUpdateError.httpStatus(503)
    }
    return .current(latestVersion: currentVersion)
  }

  func download(_ update: AppUpdate) async throws -> URL {
    throw AppUpdateError.noDownloadAsset
  }
}

@MainActor
private final class BlockingUpdateService: AppUpdateServicing {
  private let update: AppUpdate
  private var continuation: CheckedContinuation<AppUpdateCheckResult, Never>?
  private var checkCount = 0
  private(set) var checkStarted = false

  init(update: AppUpdate) {
    self.update = update
  }

  func check(currentVersion: String) async throws -> AppUpdateCheckResult {
    checkCount += 1
    if checkCount == 1 {
      return .available(update)
    }
    checkStarted = true
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
  }

  func download(_ update: AppUpdate) async throws -> URL {
    throw AppUpdateError.httpStatus(500)
  }

  func resumeCheck() {
    continuation?.resume(returning: .available(update))
    continuation = nil
  }
}

@MainActor
private final class MenuBarTestDataService: AppDataServicing {
  func loadFolders() async throws -> [AppFolder] { [] }
  func loadRules() async throws -> [StabilityExclusionRule] {
    StabilityExclusionMatcher.builtInRules
  }
  func loadHistory() async throws -> [HistoryEvent] { [] }
  func addFolder(url: URL, mode: WatchedFolderNormalizationMode) async throws -> AppFolder {
    AppFolder(
      id: UUID(),
      url: url,
      displayName: url.lastPathComponent,
      isEnabled: true,
      status: .available
    )
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
private final class MenuBarTestScanController: AppScanControlling {
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
