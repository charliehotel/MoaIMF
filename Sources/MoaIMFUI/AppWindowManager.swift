import AppKit
import SwiftUI

@MainActor
public final class AppWindowManager: NSObject, NSWindowDelegate {
  public static let shared = AppWindowManager()

  private var settingsWindow: NSWindowController?
  private var historyWindow: NSWindowController?
  private var aboutWindow: NSWindowController?
  private var launchHintWindow: NSWindowController?
  private var scanResultWindow: NSWindowController?
  private var updateWindow: NSWindowController?

  public override init() {
    super.init()
  }

  public var isSettingsVisible: Bool {
    settingsWindow?.window?.isVisible == true
  }

  public var isAboutVisible: Bool {
    aboutWindow?.window?.isVisible == true
  }

  public var isLaunchHintVisible: Bool {
    launchHintWindow?.window?.isVisible == true
  }

  var hasLaunchHintWindow: Bool {
    launchHintWindow != nil
  }

  public var isScanResultVisible: Bool {
    scanResultWindow?.window?.isVisible == true
  }

  public var isUpdateVisible: Bool {
    updateWindow?.window?.isVisible == true
  }

  var updateFrameSize: NSSize? {
    updateWindow?.window?.frame.size
  }

  var updateWindowTitle: String? {
    updateWindow?.window?.title
  }

  var updateFailureRetryAction: (@MainActor () -> Void)?

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
      self?.dismissLaunchHint(dontShowAgain: dontShowAgain, preferences: preferences)
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

  public func dismissLaunchHint(
    dontShowAgain: Bool,
    preferences: any AppPreferencesStoring
  ) {
    if dontShowAgain {
      preferences.isLaunchHintHidden = true
    }
    launchHintWindow?.window?.orderOut(nil)
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

  public func showScanResult(
    summary: ScanResultSummary,
    languageManager: LanguageManager = .shared
  ) {
    let rootView = ScanResultView(
      summary: summary,
      languageManager: languageManager
    ) { [weak self] in
      self?.scanResultWindow?.close()
    }
    if scanResultWindow == nil {
      scanResultWindow = makeWindow(
        title: MoaIMFLocalization.text("scanResult.title"),
        size: ScanResultView.preferredSize,
        minSize: ScanResultView.minimumSize,
        rootView: rootView
      )
    } else {
      let hostingController = NSHostingController(rootView: rootView)
      hostingController.sizingOptions = []
      scanResultWindow?.window?.contentViewController = hostingController
      if let window = scanResultWindow?.window {
        applyContentSizeConstraints(
          minimumSize: ScanResultView.minimumSize,
          maximumSize: nil,
          to: window
        )
      }
    }
    scanResultWindow?.window?.title = MoaIMFLocalization.text("scanResult.title")
    present(scanResultWindow)
  }

  public func showUpdateAvailable(
    update: AppUpdate,
    languageManager: LanguageManager = .shared,
    onDownload: @escaping @MainActor () -> Void
  ) {
    updateFailureRetryAction = nil
    dismissUpdateWindow()
    let rootView = UpdateAvailableView(
      update: update,
      languageManager: languageManager,
      onDownload: { [weak self] in
        self?.dismissUpdateWindow()
        onDownload()
      },
      onLater: { [weak self] in
        self?.dismissUpdateWindow()
      }
    )
    updateWindow = makeWindow(
      title: MoaIMFLocalization.text("updateAvailable.title"),
      size: UpdateAvailableView.preferredSize,
      minSize: UpdateAvailableView.preferredSize,
      maxSize: UpdateAvailableView.preferredSize,
      isResizable: false,
      rootView: rootView
    )
    present(updateWindow)
  }

  public func showUpdateCurrent(languageManager: LanguageManager = .shared) {
    updateFailureRetryAction = nil
    dismissUpdateWindow()
    let rootView = UpdateCurrentView(
      languageManager: languageManager,
      onDismiss: { [weak self] in
        self?.dismissUpdateWindow()
      }
    )
    updateWindow = makeWindow(
      title: MoaIMFLocalization.text("updateCurrent.title"),
      size: UpdateCurrentView.preferredSize,
      minSize: UpdateCurrentView.preferredSize,
      maxSize: UpdateCurrentView.preferredSize,
      isResizable: false,
      rootView: rootView
    )
    present(updateWindow)
  }

  public func showUpdateFailure(
    message: String,
    languageManager: LanguageManager = .shared,
    onRetry: @escaping @MainActor () -> Void = {}
  ) {
    dismissUpdateWindow()
    updateFailureRetryAction = { [weak self] in
      self?.dismissUpdateWindow()
      onRetry()
    }
    let rootView = UpdateFailureView(
      message: message,
      languageManager: languageManager,
      onRetry: { [weak self] in
        self?.updateFailureRetryAction?()
      }
    )
    updateWindow = makeWindow(
      title: MoaIMFLocalization.text("menu.updateFailed"),
      size: UpdateFailureView.preferredSize,
      minSize: UpdateFailureView.preferredSize,
      maxSize: UpdateFailureView.preferredSize,
      isResizable: false,
      rootView: rootView
    )
    present(updateWindow)
  }

  private func dismissUpdateWindow() {
    updateWindow?.close()
    updateWindow = nil
  }

  public func closeAll() {
    aboutWindow?.close()
    aboutWindow = nil
    settingsWindow?.close()
    settingsWindow = nil
    historyWindow?.close()
    historyWindow = nil
    launchHintWindow?.close()
    launchHintWindow = nil
    scanResultWindow?.close()
    scanResultWindow = nil
    updateWindow?.close()
    updateWindow = nil
    updateFailureRetryAction = nil
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
    window.delegate = self
    if minSize != nil || maxSize != nil {
      applyContentSizeConstraints(
        minimumSize: minSize,
        maximumSize: maxSize,
        to: window
      )
    }
    window.setContentSize(size)
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
    guard let window = controller?.window else { return }
    controller?.showWindow(nil)
    window.orderFrontRegardless()
    window.makeKey()
    NSApplication.shared.activate(ignoringOtherApps: true)
  }

  public func windowWillClose(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }
    if window == updateWindow?.window {
      updateWindow = nil
    } else if window == settingsWindow?.window {
      settingsWindow = nil
    } else if window == historyWindow?.window {
      historyWindow = nil
    } else if window == aboutWindow?.window {
      aboutWindow = nil
    } else if window == launchHintWindow?.window {
      launchHintWindow = nil
    } else if window == scanResultWindow?.window {
      scanResultWindow = nil
    }
  }
}
