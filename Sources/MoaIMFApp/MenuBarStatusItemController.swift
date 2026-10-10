import AppKit
import Combine
import MoaIMFUI

@MainActor
final class MenuBarStatusItemController: NSObject {
  private let controller: AppController
  private let menuBuilder: MenuBarMenuBuilder
  private let statusItem: NSStatusItem
  private var cancellables = Set<AnyCancellable>()
  private var refreshTask: Task<Void, Never>?

  init(controller: AppController, languageManager: LanguageManager) {
    self.controller = controller
    menuBuilder = MenuBarMenuBuilder(
      controller: controller,
      languageManager: languageManager
    )
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    super.init()

    statusItem.menu = menuBuilder.menu
    subscribeToChanges(languageManager: languageManager)
    refresh()
  }

  private func subscribeToChanges(languageManager: LanguageManager) {
    controller.objectWillChange
      .sink { [weak self] _ in self?.scheduleRefresh() }
      .store(in: &cancellables)
    controller.loginItemManager.objectWillChange
      .sink { [weak self] _ in self?.scheduleRefresh() }
      .store(in: &cancellables)
    languageManager.objectWillChange
      .sink { [weak self] _ in self?.scheduleRefresh() }
      .store(in: &cancellables)
  }

  private func scheduleRefresh() {
    refreshTask?.cancel()
    refreshTask = Task { @MainActor [weak self] in
      await Task.yield()
      guard !Task.isCancelled else { return }
      self?.refresh()
    }
  }

  private func refresh() {
    menuBuilder.rebuild()
    statusItem.button?.image =
      MenuBarIconAssets.frames.first
      ?? NSImage(
        systemSymbolName: controller.status.symbolName,
        accessibilityDescription: nil
      )
    statusItem.button?.image?.isTemplate = true
    if let progress = controller.scanProgress {
      let progressText =
        progress.phase == .scanning
        ? MoaIMFLocalization.text("status.scanningFiles")
        : String(
          format: MoaIMFLocalization.text("menu.progressNormalizing"),
          progress.folderName,
          progress.completed,
          progress.total,
          progress.percentage
        )
      statusItem.button?.toolTip = progressText
    } else {
      statusItem.button?.toolTip = MoaIMFLocalization.text(
        controller.status.localizationKey
      )
    }
  }
}
