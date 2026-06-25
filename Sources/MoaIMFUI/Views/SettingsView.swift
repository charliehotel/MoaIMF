import SwiftUI

public struct SettingsView: View {
  @ObservedObject private var controller: AppController
  @ObservedObject private var languageManager: LanguageManager

  public init(controller: AppController, languageManager: LanguageManager? = nil) {
    self.controller = controller
    self.languageManager = languageManager ?? controller.languageManager
  }

  public var body: some View {
    let _ = languageManager.selection

    Group {
      if controller.folders.isEmpty {
        FirstRunView(controller: controller)
      } else {
        TabView {
          WatchedFoldersView(controller: controller)
            .tabItem { Label(MoaIMFLocalization.text("folder.add"), systemImage: "folder") }
          StabilityRulesView(controller: controller)
            .tabItem { Label(MoaIMFLocalization.text("stability.title"), systemImage: "hourglass") }
        }
        .padding(20)
        .frame(minWidth: 680, minHeight: 460)
      }
    }
    .id(languageManager.selection)
    .background(WindowTitleUpdater(title: MoaIMFLocalization.text("menu.settings")))
    .alert(
      controller.alert.map { MoaIMFLocalization.text($0.localizationKey) } ?? "",
      isPresented: Binding(
        get: { controller.alert != nil },
        set: { if !$0 { controller.dismissAlert() } }
      )
    ) {
      Button(MoaIMFLocalization.text("common.ok")) { controller.dismissAlert() }
    } message: {
      if let detail = controller.alert?.detail { Text(detail) }
    }
  }
}

private struct WindowTitleUpdater: NSViewRepresentable {
  let title: String

  func makeNSView(context: Context) -> NSView {
    NSView(frame: .zero)
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    Task { @MainActor in
      nsView.window?.title = title
    }
  }
}
