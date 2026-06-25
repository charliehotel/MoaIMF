import AppKit
import SwiftUI

public struct LaunchHintView: View {
  public static let preferredSize = NSSize(width: 420, height: 276)

  @ObservedObject private var languageManager: LanguageManager
  @State private var dontShowAgain = false
  private let onDismiss: @MainActor (Bool) -> Void

  public init(
    languageManager: LanguageManager = .shared,
    onDismiss: @escaping @MainActor (Bool) -> Void = { _ in }
  ) {
    self.languageManager = languageManager
    self.onDismiss = onDismiss
  }

  public var body: some View {
    VStack(spacing: 8) {
      PopupImage()
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityLabel(MoaIMFLocalization.text("launchHint.title"))

      HStack {
        Toggle(MoaIMFLocalization.text("launchHint.dontShowAgain"), isOn: $dontShowAgain)
          .toggleStyle(.checkbox)

        Spacer()

        Button(MoaIMFLocalization.text("common.ok")) {
          onDismiss(dontShowAgain)
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .id(languageManager.selection)
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 8)
    .frame(width: Self.preferredSize.width, height: Self.preferredSize.height)
  }
}

private struct PopupImage: View {
  var body: some View {
    if let image = Self.image {
      Image(nsImage: image)
        .resizable()
        .aspectRatio(contentMode: .fit)
    } else {
      VStack(spacing: 8) {
        Image(systemName: "menubar.arrow.up.rectangle")
          .font(.largeTitle)
        Text(MoaIMFLocalization.text("launchHint.body"))
          .font(.callout)
          .multilineTextAlignment(.center)
      }
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(.quaternary)
    }
  }

  private static let image: NSImage? = {
    let fileName = "popup.png"
    let resourcePaths = [
      Bundle.main.resourceURL?.appendingPathComponent("Assets.xcassets/\(fileName)"),
      URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("Assets.xcassets/\(fileName)"),
    ]
    for url in resourcePaths.compactMap({ $0 }) {
      if let image = NSImage(contentsOf: url) {
        return image
      }
    }
    return nil
  }()
}
