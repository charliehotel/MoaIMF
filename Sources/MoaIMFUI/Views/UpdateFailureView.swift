import SwiftUI

public struct UpdateFailureView: View {
  public static let preferredSize = NSSize(width: 500, height: 240)

  let message: String
  @ObservedObject private var languageManager: LanguageManager
  private let onRetry: @MainActor () -> Void

  public init(
    message: String,
    languageManager: LanguageManager = .shared,
    onRetry: @escaping @MainActor () -> Void = {}
  ) {
    self.message = message
    self.languageManager = languageManager
    self.onRetry = onRetry
  }

  public var body: some View {
    let _ = languageManager.selection

    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.title2)
          .foregroundStyle(.red)

        Text(MoaIMFLocalization.text("menu.updateFailed"))
          .font(.body)
          .fontWeight(.semibold)
      }

      ScrollView {
        Text(message)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
      .frame(maxHeight: 90)

      HStack {
        Spacer()
        Button(MoaIMFLocalization.text("common.ok")) {
          onRetry()
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
