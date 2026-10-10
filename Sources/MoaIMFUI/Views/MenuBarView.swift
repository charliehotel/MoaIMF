import SwiftUI

public struct MenuBarView: View {
  @ObservedObject private var controller: AppController
  @ObservedObject private var loginItemManager: LoginItemManager
  @ObservedObject private var languageManager: LanguageManager

  public init(controller: AppController) {
    self.controller = controller
    loginItemManager = controller.loginItemManager
    languageManager = controller.languageManager
  }

  public var body: some View {
    Button(MoaIMFLocalization.text("menu.about")) {
      AppWindowManager.shared.showAbout(languageManager: languageManager)
    }

    Divider()

    Button(todayRenameSummary) {
      AppWindowManager.shared.showHistory(
        controller: controller,
        dateScope: .today,
        filter: .renamed
      )
    }

    Button(
      MoaIMFLocalization.text(controller.isPaused ? "menu.resume" : "menu.pause")
    ) {
      Task { await controller.setPaused(!controller.isPaused) }
    }
    .keyboardShortcut("p")

    Button(MoaIMFLocalization.text("menu.scanAll")) {
      Task { await controller.scanAll() }
    }
    .disabled(controller.folders.isEmpty || controller.isScanning)
    .keyboardShortcut("r")

    if let progress = controller.scanProgress {
      Label(
        progress.phase == .scanning
          ? MoaIMFLocalization.text("status.scanningFiles")
          : String(
            format: MoaIMFLocalization.text("menu.progressNormalizing"),
            progress.folderName,
            progress.completed,
            progress.total,
            progress.percentage
          ),
        systemImage: "arrow.triangle.2.circlepath"
      )
      .foregroundStyle(.secondary)
    }

    Divider()

    Button(MoaIMFLocalization.text("menu.settings")) {
      AppWindowManager.shared.showSettings(controller: controller)
    }
    Button(MoaIMFLocalization.text("menu.history")) {
      AppWindowManager.shared.showHistory(controller: controller, dateScope: .today)
    }

    Menu(MoaIMFLocalization.text("menu.language")) {
      ForEach(MoaIMFLanguage.allCases) { language in
        Button {
          languageManager.setLanguage(language)
        } label: {
          if languageManager.selection == language {
            Label(
              MoaIMFLocalization.text(language.localizationKey),
              systemImage: "checkmark"
            )
          } else {
            Text(MoaIMFLocalization.text(language.localizationKey))
          }
        }
      }
    }

    if let update = automaticDownloadCandidate {
      UpdateMenuItemRepresentable(
        update: update,
        onCheck: { checkForUpdatesManually() },
        onDownload: { downloadAvailableUpdate() }
      )
      .frame(height: UpdateMenuItemView.rowHeight)
    } else {
      updateCheckButton
    }

    if controller.updateCheckStatus == .downloaded {
      Label(
        MoaIMFLocalization.text("menu.updateDownloaded"),
        systemImage: "checkmark.circle"
      )
      .foregroundStyle(.secondary)
    }

    Toggle(
      MoaIMFLocalization.text("menu.loginAtLaunch"),
      isOn: Binding(
        get: { loginItemManager.state == .enabled },
        set: { loginItemManager.setEnabled($0) }
      )
    )
    if loginItemManager.state == .requiresApproval {
      Button(MoaIMFLocalization.text("menu.loginOpenSettings")) {
        loginItemManager.openSystemSettings()
      }
    }

    Divider()

    Button(MoaIMFLocalization.text("menu.quit")) {
      Task { await controller.quit() }
    }
    .keyboardShortcut("q")
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

  var automaticDownloadCandidate: AppUpdate? {
    guard controller.updateCheckStatus != .downloading,
      controller.updateCheckStatus != .downloaded,
      controller.updateCheckStatus != .failed
    else {
      return nil
    }
    return controller.automaticAvailableUpdate
  }

  private var updateCheckButton: some View {
    Button(updateCheckTitle) {
      checkForUpdatesManually()
    }
    .disabled(
      controller.updateCheckStatus == .checking
        || controller.updateCheckStatus == .downloading
    )
  }

  private func checkForUpdatesManually() {
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
        ) {
          downloadAvailableUpdate()
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
      onRetry: { checkForUpdatesManually() }
    )
  }

  private func downloadAvailableUpdate() {
    Task { await controller.downloadAvailableUpdate() }
  }
}
