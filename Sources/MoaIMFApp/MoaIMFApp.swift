import AppKit
import MoaIMFUI
import SwiftUI

@main
@MainActor
struct MoaIMFApp: App {
  private let preferences: UserDefaultsAppPreferences
  @StateObject private var controller: AppController
  @StateObject private var languageManager: LanguageManager

  init() {
    let preferences = UserDefaultsAppPreferences()
    let languageManager = LanguageManager(preferences: preferences)
    let controller = MoaIMFEnvironment.makeController(
      preferences: preferences,
      languageManager: languageManager
    ) {
      NSApplication.shared.terminate(nil)
    }
    self.preferences = preferences
    _controller = StateObject(wrappedValue: controller)
    _languageManager = StateObject(wrappedValue: languageManager)
  }

  var body: some Scene {
    let _ = languageManager.selection

    MenuBarExtra {
      MenuBarView(controller: controller)
        .task { await controller.load() }
    } label: {
      Label {
        Text("MoaIMF, \(MoaIMFLocalization.text(controller.status.localizationKey))")
      } icon: {
        MenuBarIconLabel(controller: controller)
      }
      .labelStyle(.iconOnly)
      .onAppear {
        AppWindowManager.shared.showLaunchHintIfNeeded(
          preferences: preferences,
          languageManager: languageManager
        )
      }
    }
    .menuBarExtraStyle(.menu)
    .commands {
      CommandGroup(replacing: .appInfo) {
        Button(MoaIMFLocalization.text("menu.about")) {
          AppWindowManager.shared.showAbout(languageManager: languageManager)
        }
      }
    }

    Settings {
      SettingsView(controller: controller, languageManager: languageManager)
        .task { await controller.load() }
    }

    Window(MoaIMFLocalization.text("history.title"), id: "history") {
      HistoryView(controller: controller)
        .frame(width: HistoryView.preferredSize.width, height: HistoryView.preferredSize.height)
        .task { await controller.load() }
    }
    .defaultSize(width: HistoryView.preferredSize.width, height: HistoryView.preferredSize.height)
    .windowResizability(.contentSize)

  }
}
