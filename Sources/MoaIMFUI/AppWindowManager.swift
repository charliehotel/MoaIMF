import AppKit
import SwiftUI

@MainActor
public final class AppWindowManager {
  public static let shared = AppWindowManager()

  private var settingsWindow: NSWindowController?
  private var historyWindow: NSWindowController?
  private var aboutWindow: NSWindowController?
  private var launchHintWindow: NSWindowController?

  public init() {}

  public var isSettingsVisible: Bool {
    settingsWindow?.window?.isVisible == true
  }

  public var isAboutVisible: Bool {
    aboutWindow?.window?.isVisible == true
  }

  public var isLaunchHintVisible: Bool {
    launchHintWindow?.window?.isVisible == true
  }

  var historyContentMinimumSize: NSSize? {
    historyWindow?.window?.contentMinSize
  }

  var historyFrameMinimumSize: NSSize? {
    historyWindow?.window?.minSize
  }

  var historyFrameMaximumSize: NSSize? {
    historyWindow?.window?.maxSize
  }

  var isHistoryResizable: Bool {
    historyWindow?.window?.styleMask.contains(.resizable) == true
  }

  public func showAbout(languageManager: LanguageManager = .shared) {
    if aboutWindow == nil {
      aboutWindow = makeWindow(
        title: MoaIMFLocalization.text("menu.about"),
        size: NSSize(width: 420, height: 300),
        rootView: AboutView(languageManager: languageManager)
      )
    }
    aboutWindow?.window?.title = MoaIMFLocalization.text("menu.about")
    present(aboutWindow)
  }

  public func showSettings(controller: AppController) {
    if settingsWindow == nil {
      settingsWindow = makeWindow(
        title: MoaIMFLocalization.text("menu.settings"),
        size: NSSize(width: 720, height: 520),
        rootView: SettingsView(controller: controller)
      )
    }
    settingsWindow?.window?.title = MoaIMFLocalization.text("menu.settings")
    present(settingsWindow)
  }

  public func showLaunchHintIfNeeded(
    preferences: any AppPreferencesStoring,
    languageManager: LanguageManager = .shared
  ) {
    guard !preferences.isLaunchHintHidden else { return }
    showLaunchHint(preferences: preferences, languageManager: languageManager)
  }

  public func showLaunchHint(
    preferences: any AppPreferencesStoring,
    languageManager: LanguageManager = .shared
  ) {
    let rootView = LaunchHintView(languageManager: languageManager) { [weak self] dontShowAgain in
      if dontShowAgain {
        preferences.isLaunchHintHidden = true
      }
      self?.launchHintWindow?.close()
    }
    if launchHintWindow == nil {
      launchHintWindow = makeWindow(
        title: MoaIMFLocalization.text("app.name"),
        size: LaunchHintView.preferredSize,
        minSize: LaunchHintView.preferredSize,
        maxSize: LaunchHintView.preferredSize,
        isResizable: false,
        rootView: rootView
      )
    } else {
      let hostingController = NSHostingController(rootView: rootView)
      hostingController.sizingOptions = []
      launchHintWindow?.window?.contentViewController = hostingController
    }
    launchHintWindow?.window?.title = MoaIMFLocalization.text("app.name")
    present(launchHintWindow)
  }

  public func showHistory(
    controller: AppController,
    dateScope: HistoryDateScope = .today,
    filter: HistoryFilter = .all
  ) {
    let rootView = HistoryView(controller: controller, dateScope: dateScope, filter: filter)
    if historyWindow == nil {
      historyWindow = makeWindow(
        title: MoaIMFLocalization.text("history.title"),
        size: HistoryView.preferredSize,
        minSize: HistoryView.minimumSize,
        maxSize: HistoryView.preferredSize,
        isResizable: false,
        rootView: rootView
      )
    } else {
      let hostingController = NSHostingController(rootView: rootView)
      hostingController.sizingOptions = []
      historyWindow?.window?.contentViewController = hostingController
      if let window = historyWindow?.window {
        applyContentSizeConstraints(
          minimumSize: HistoryView.minimumSize,
          maximumSize: HistoryView.preferredSize,
          to: window
        )
        window.setContentSize(HistoryView.preferredSize)
        window.styleMask.remove(.resizable)
      }
    }
    historyWindow?.window?.title = MoaIMFLocalization.text("history.title")
    present(historyWindow)
  }

  public func closeAll() {
    aboutWindow?.close()
    settingsWindow?.close()
    historyWindow?.close()
    launchHintWindow?.close()
  }

  private func makeWindow<Content: View>(
    title: String,
    size: NSSize,
    minSize: NSSize? = nil,
    maxSize: NSSize? = nil,
    isResizable: Bool = true,
    rootView: Content
  ) -> NSWindowController {
    var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable]
    if isResizable {
      styleMask.insert(.resizable)
    }
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: styleMask,
      backing: .buffered,
      defer: false
    )
    let hostingController = NSHostingController(rootView: rootView)
    hostingController.sizingOptions = []
    window.title = title
    window.contentViewController = hostingController
    if minSize != nil || maxSize != nil {
      applyContentSizeConstraints(
        minimumSize: minSize,
        maximumSize: maxSize,
        to: window
      )
    }
    window.isReleasedWhenClosed = false
    window.center()
    return NSWindowController(window: window)
  }

  private func applyContentSizeConstraints(
    minimumSize: NSSize?,
    maximumSize: NSSize?,
    to window: NSWindow
  ) {
    if let minimumSize {
      window.contentMinSize = minimumSize
      window.minSize =
        window
        .frameRect(forContentRect: NSRect(origin: .zero, size: minimumSize))
        .size
    }

    if let maximumSize {
      window.contentMaxSize = maximumSize
      window.maxSize =
        window
        .frameRect(forContentRect: NSRect(origin: .zero, size: maximumSize))
        .size
    }

    let currentContentSize = window.contentLayoutRect.size
    guard currentContentSize.width > 0, currentContentSize.height > 0 else { return }

    let clampedContentSize = NSSize(
      width: min(
        max(currentContentSize.width, minimumSize?.width ?? currentContentSize.width),
        maximumSize?.width ?? currentContentSize.width
      ),
      height: min(
        max(currentContentSize.height, minimumSize?.height ?? currentContentSize.height),
        maximumSize?.height ?? currentContentSize.height
      )
    )
    if clampedContentSize != currentContentSize {
      window.setContentSize(clampedContentSize)
    }
  }

  private func present(_ controller: NSWindowController?) {
    controller?.showWindow(nil)
    controller?.window?.makeKeyAndOrderFront(nil)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}
