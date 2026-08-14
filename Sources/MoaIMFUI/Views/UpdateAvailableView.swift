import SwiftUI

public struct UpdateAvailableView: View {
  public static let preferredSize = NSSize(width: 500, height: 360)

  let update: AppUpdate
  @ObservedObject private var languageManager: LanguageManager
  private let onDownload: () -> Void
  private let onLater: () -> Void

  public init(
    update: AppUpdate,
    languageManager: LanguageManager = .shared,
    onDownload: @escaping () -> Void = {},
    onLater: @escaping () -> Void = {}
  ) {
    self.update = update
    self.languageManager = languageManager
    self.onDownload = onDownload
    self.onLater = onLater
  }

  public var body: some View {
    let _ = languageManager.selection

    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "arrow.down.circle.fill")
          .font(.title2)
          .foregroundStyle(.tint)

        VStack(alignment: .leading, spacing: 4) {
          Text(MoaIMFLocalization.text("updateAvailable.title"))
            .font(.body)
            .fontWeight(.semibold)
          Text(
            String(
              format: MoaIMFLocalization.text("updateAvailable.version"),
              update.tagName
            )
          )
          .foregroundStyle(.secondary)
        }
      }

      Divider()

      Text(MoaIMFLocalization.text("updateAvailable.notesTitle"))
        .font(.headline)

      ScrollView {
        Text(formattedReleaseNotes)
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
      .frame(maxHeight: 180)

      HStack {
        Spacer()
        Button(MoaIMFLocalization.text("updateAvailable.later"), role: .cancel) {
          onLater()
        }
        Button(MoaIMFLocalization.text("updateAvailable.download")) {
          onDownload()
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

  private var formattedReleaseNotes: AttributedString {
    let notes =
      update.releaseNotes.isEmpty
      ? MoaIMFLocalization.text("updateAvailable.noNotes")
      : update.releaseNotes
    let displayNotes =
      notes
      .components(separatedBy: .newlines)
      .map { line in
        let withoutHeading = line.replacingOccurrences(
          of: #"^\s{0,3}#{1,6}\s+"#,
          with: "",
          options: .regularExpression
        )
        return withoutHeading.replacingOccurrences(
          of: #"^\s*[-*+]\s+"#,
          with: "• ",
          options: .regularExpression
        )
      }
      .joined(separator: "\n")
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace
    )
    return (try? AttributedString(markdown: displayNotes, options: options))
      ?? AttributedString(displayNotes)
  }
}
