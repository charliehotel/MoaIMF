import SwiftUI

public struct UpdateCurrentView: View {
  public static let preferredSize = NSSize(width: 420, height: 180)

  @ObservedObject private var languageManager: LanguageManager
  private let onDismiss: () -> Void

  public init(
    languageManager: LanguageManager = .shared,
    onDismiss: @escaping () -> Void = {}
  ) {
    self.languageManager = languageManager
    self.onDismiss = onDismiss
  }

  public var body: some View {
    let _ = languageManager.selection

    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "checkmark.circle.fill")
          .font(.title2)
          .foregroundStyle(.green)

        VStack(alignment: .leading, spacing: 4) {
          Text(MoaIMFLocalization.text("updateCurrent.title"))
            .font(.body)
            .fontWeight(.semibold)
          Text(MoaIMFLocalization.text("updateCurrent.body"))
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      HStack {
        Spacer()
        Button(MoaIMFLocalization.text("common.ok")) {
          onDismiss()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(
      width: Self.preferredSize.width,
      height: Self.preferredSize.height,
      alignment: .topLeading
    )
  }
}
