import AppKit
import MoaIMFUI
import SwiftUI

@main
@MainActor
struct MoaIMFApp: App {
  @NSApplicationDelegateAdaptor(MoaIMFApplicationDelegate.self)
  private var applicationDelegate
  private let preferences: UserDefaultsAppPreferences
  @StateObject private var controller: AppController
  @StateObject private var languageManager: LanguageManager
  private let menuBarController: MenuBarStatusItemController

  init() {
    let preferences = UserDefaultsAppPreferences()
    let languageManager = LanguageManager(preferences: preferences)
    let controller = MoaIMFEnvironment.makeController(
      preferences: preferences,
      languageManager: languageManager,
      automaticallyCheckForUpdates: true
    ) {
      NSApplication.shared.terminate(nil)
    }
    self.preferences = preferences
    _controller = StateObject(wrappedValue: controller)
    _languageManager = StateObject(wrappedValue: languageManager)
    menuBarController = MenuBarStatusItemController(
      controller: controller,
      languageManager: languageManager
    )
    AppWindowManager.shared.showLaunchHintIfNeeded(
      preferences: preferences,
      languageManager: languageManager
    )
    Task { await controller.load() }
  }

  var body: some Scene {
    Settings {
      SettingsView(controller: controller, languageManager: languageManager)
        .task { await controller.load() }
    }
    .commands {
      CommandGroup(replacing: .appInfo) {
        Button(MoaIMFLocalization.text("menu.about")) {
          AppWindowManager.shared.showAbout(languageManager: languageManager)
        }
      }
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
