import AppKit
import Foundation

@MainActor
public final class MenuBarMenuBuilder: NSObject {
  public static let updateMenuItemTag = 1_001
  private static let uncheckedStateColumnImage = NSImage(
    size: NSSize(width: 13, height: 11)
  )

  public let menu = NSMenu()

  private let controller: AppController
  private let languageManager: LanguageManager

  public init(
    controller: AppController,
    languageManager: LanguageManager? = nil
  ) {
    self.controller = controller
    self.languageManager = languageManager ?? controller.languageManager
    super.init()
    menu.autoenablesItems = false
    rebuild()
  }

  public func rebuild() {
    menu.removeAllItems()

    menu.addItem(
      actionItem(
        title: MoaIMFLocalization.text("menu.about"),
        action: #selector(showAbout)
      ))
    menu.addItem(.separator())

    menu.addItem(
      actionItem(
        title: todayRenameSummary,
        action: #selector(showTodayRenamedHistory)
      ))
    let pauseItem = actionItem(
      title: MoaIMFLocalization.text(controller.isPaused ? "menu.resume" : "menu.pause"),
      action: #selector(togglePause)
    )
    pauseItem.keyEquivalent = "p"
    pauseItem.keyEquivalentModifierMask = [.command]
    menu.addItem(pauseItem)

    let scanItem = actionItem(
      title: MoaIMFLocalization.text("menu.scanAll"),
      action: #selector(scanAll)
    )
    scanItem.isEnabled = !controller.folders.isEmpty && !controller.isScanning
    scanItem.keyEquivalent = "r"
    scanItem.keyEquivalentModifierMask = [.command]
    menu.addItem(scanItem)

    if let progress = controller.scanProgress {
      let progressTitle =
        progress.phase == .scanning
        ? MoaIMFLocalization.text("status.scanningFiles")
        : String(
          format: MoaIMFLocalization.text("menu.progressNormalizing"),
          progress.folderName,
          progress.completed,
          progress.total,
          progress.percentage
        )
      let progressItem = NSMenuItem(
        title: progressTitle,
        action: nil,
        keyEquivalent: ""
      )
      progressItem.isEnabled = false
      menu.addItem(progressItem)
    }

    menu.addItem(.separator())
    menu.addItem(
      actionItem(
        title: MoaIMFLocalization.text("menu.settings"),
        action: #selector(showSettings)
      ))
    menu.addItem(
      actionItem(
        title: MoaIMFLocalization.text("menu.history"),
        action: #selector(showHistory)
      ))
    menu.addItem(languageMenuItem())

    if let update = automaticDownloadCandidate {
      menu.addItem(updateMenuItem(for: update))
    } else {
      let updateItem = actionItem(
        title: updateCheckTitle,
        action: #selector(checkForUpdates)
      )
      updateItem.tag = Self.updateMenuItemTag
      updateItem.isEnabled =
        controller.updateCheckStatus != .checking
        && controller.updateCheckStatus != .downloading
      menu.addItem(updateItem)
    }

    if controller.updateCheckStatus == .downloaded {
      let downloadedItem = NSMenuItem(
        title: MoaIMFLocalization.text("menu.updateDownloaded"),
        action: nil,
        keyEquivalent: ""
      )
      downloadedItem.isEnabled = false
      menu.addItem(downloadedItem)
    }

    let loginItem = actionItem(
      title: MoaIMFLocalization.text("menu.loginAtLaunch"),
      action: #selector(toggleLoginAtLaunch)
    )
    loginItem.state = controller.loginItemManager.state == .enabled ? .on : .off
    loginItem.offStateImage = Self.uncheckedStateColumnImage
    menu.addItem(loginItem)

    if controller.loginItemManager.state == .requiresApproval {
      menu.addItem(
        actionItem(
          title: MoaIMFLocalization.text("menu.loginOpenSettings"),
          action: #selector(openLoginSettings)
        ))
    }

    menu.addItem(.separator())
    let quitItem = actionItem(
      title: MoaIMFLocalization.text("menu.quit"),
      action: #selector(quit)
    )
    quitItem.keyEquivalent = "q"
    quitItem.keyEquivalentModifierMask = [.command]
    menu.addItem(quitItem)
  }

  private var todayRenameSummary: String {
    String(
      format: MoaIMFLocalization.text("menu.todayRenamedCount"),
      controller.todaysRenameCount
    )
  }

  private var updateCheckTitle: String {
    switch controller.updateCheckStatus {
    case .idle, .current, .available, .downloaded:
      MoaIMFLocalization.text("menu.checkForUpdates")
    case .checking:
      MoaIMFLocalization.text("menu.updateChecking")
    case .downloading:
      MoaIMFLocalization.text("menu.updateDownloading")
    case .failed:
      MoaIMFLocalization.text("menu.updateFailed")
    }
  }

  private var automaticDownloadCandidate: AppUpdate? {
    guard controller.updateCheckStatus != .downloading,
      controller.updateCheckStatus != .downloaded,
      controller.updateCheckStatus != .failed
    else {
      return nil
    }
    return controller.automaticAvailableUpdate
  }

  private func actionItem(title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  private func languageMenuItem() -> NSMenuItem {
    let submenu = NSMenu()
    submenu.autoenablesItems = false
    for language in MoaIMFLanguage.allCases {
      let item = NSMenuItem(
        title: MoaIMFLocalization.text(language.localizationKey),
        action: #selector(selectLanguage(_:)),
        keyEquivalent: ""
      )
      item.target = self
      item.representedObject = language.rawValue
      item.state = languageManager.selection == language ? .on : .off
      submenu.addItem(item)
    }

    let item = NSMenuItem(
      title: MoaIMFLocalization.text("menu.language"),
      action: nil,
      keyEquivalent: ""
    )
    item.submenu = submenu
    return item
  }

  private func updateMenuItem(for update: AppUpdate) -> NSMenuItem {
    let item = NSMenuItem()
    item.tag = Self.updateMenuItemTag
    let view = UpdateMenuItemView(
      update: update,
      onCheck: { [weak self] in self?.checkForUpdates() },
      onDownload: { [weak self] in self?.downloadAvailableUpdate() }
    )
    let size = view.intrinsicContentSize
    view.frame = NSRect(
      x: 0,
      y: 0,
      width: max(size.width, 220),
      height: size.height
    )
    item.view = view
    return item
  }

  @objc private func showAbout() {
    AppWindowManager.shared.showAbout(languageManager: languageManager)
  }

  @objc private func showTodayRenamedHistory() {
    AppWindowManager.shared.showHistory(
      controller: controller,
      dateScope: .today,
      filter: .renamed
    )
  }

  @objc private func togglePause() {
    Task { await controller.setPaused(!controller.isPaused) }
  }

  @objc private func scanAll() {
    Task { await controller.scanAll() }
  }

  @objc private func showSettings() {
    AppWindowManager.shared.showSettings(controller: controller)
  }

  @objc private func showHistory() {
    AppWindowManager.shared.showHistory(controller: controller)
  }

  @objc private func selectLanguage(_ sender: NSMenuItem) {
    guard
      let rawValue = sender.representedObject as? String,
      let language = MoaIMFLanguage(rawValue: rawValue)
    else { return }
    languageManager.setLanguage(language)
  }

  @objc private func checkForUpdates() {
    Task {
      guard let result = await controller.checkForUpdates() else {
        showManualUpdateFailureIfNeeded()
        return
      }
      switch result {
      case .current:
        AppWindowManager.shared.showUpdateCurrent(languageManager: languageManager)
      case .available(let update):
        AppWindowManager.shared.showUpdateAvailable(
          update: update,
          languageManager: languageManager
        ) { [weak self] in
          self?.downloadAvailableUpdate()
        }
      }
    }
  }

  private func showManualUpdateFailureIfNeeded() {
    guard controller.updateCheckStatus == .failed else { return }
    AppWindowManager.shared.showUpdateFailure(
      message: controller.updateErrorMessage
        ?? MoaIMFLocalization.text("menu.updateFailed"),
      languageManager: languageManager,
      onRetry: { [weak self] in self?.checkForUpdates() }
    )
  }

  @objc private func downloadAvailableUpdate() {
    Task { await controller.downloadAvailableUpdate() }
  }

  @objc private func toggleLoginAtLaunch() {
    controller.loginItemManager.setEnabled(controller.loginItemManager.state != .enabled)
  }

  @objc private func openLoginSettings() {
    controller.loginItemManager.openSystemSettings()
  }

  @objc private func quit() {
    Task { await controller.quit() }
  }
}
