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
    Label(
      MoaIMFLocalization.text(controller.status.localizationKey),
      systemImage: controller.status.symbolName
    )
    .accessibilityLabel(MoaIMFLocalization.text(controller.status.localizationKey))

    Button(todayRenameSummary) {
      AppWindowManager.shared.showHistory(
        controller: controller,
        dateScope: .today,
        filter: .renamed
      )
    }

    Button(MoaIMFLocalization.text("menu.about")) {
      AppWindowManager.shared.showAbout(languageManager: languageManager)
    }

    Divider()

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

    Toggle(
      MoaIMFLocalization.text("menu.loginAtLaunch"),
      isOn: Binding(
        get: { loginItemManager.state == .enabled },
        set: { loginItemManager.setEnabled($0) }
      )
    )
    LoginItemStatusView(state: loginItemManager.state, languageManager: languageManager)

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
}

struct LoginItemStatusView: View {
  let state: LoginItemState
  @ObservedObject private var languageManager: LanguageManager

  init(
    state: LoginItemState,
    languageManager: LanguageManager = .shared
  ) {
    self.state = state
    self.languageManager = languageManager
  }

  var body: some View {
    let language = languageManager.selection

    Label(
      MoaIMFLocalization.text(state.menuLocalizationKey),
      systemImage: state.menuSystemImage
    )
    .id("\(state)-\(language.rawValue)")
    .font(.caption)
    .foregroundStyle(.secondary)
  }
}
