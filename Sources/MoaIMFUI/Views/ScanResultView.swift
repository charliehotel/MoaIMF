import AppKit
import MoaIMFCore
import SwiftUI

public struct ScanResultView: View {
  public static let preferredSize = NSSize(width: 560, height: 420)
  public static let minimumSize = NSSize(width: 480, height: 320)

  public let summary: ScanResultSummary
  @ObservedObject private var languageManager: LanguageManager
  private let onClose: () -> Void

  public init(
    summary: ScanResultSummary,
    languageManager: LanguageManager = .shared,
    onClose: @escaping () -> Void = {}
  ) {
    self.summary = summary
    self.languageManager = languageManager
    self.onClose = onClose
  }

  public var body: some View {
    let _ = languageManager.selection

    VStack(alignment: .leading, spacing: 16) {
      header

      Text(summaryText)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      Divider()

      ScrollView {
        resultDetails
          .frame(maxWidth: .infinity, alignment: .leading)
      }

      HStack {
        Spacer()
        Button(MoaIMFLocalization.text("common.ok")) {
          onClose()
        }
        .keyboardShortcut(.defaultAction)
      }
    }
    .padding(24)
    .frame(
      minWidth: Self.minimumSize.width,
      minHeight: Self.minimumSize.height,
      alignment: .topLeading
    )
  }

  private var header: some View {
    HStack(alignment: .top, spacing: 12) {
      Image(systemName: hasProblems ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
        .font(.title)
        .foregroundStyle(hasProblems ? .orange : .green)

      VStack(alignment: .leading, spacing: 4) {
        Text(MoaIMFLocalization.text("scanResult.title"))
          .font(.title2.weight(.semibold))
        if summary.errorMessage != nil {
          Text(MoaIMFLocalization.text("scanResult.error"))
            .font(.callout)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  @ViewBuilder
  private var resultDetails: some View {
    if let errorMessage = summary.errorMessage {
      Label {
        Text(errorMessage)
          .textSelection(.enabled)
      } icon: {
        Image(systemName: "xmark.circle")
          .foregroundStyle(.red)
      }
      .font(.callout)
    }

    if summary.renamedOutcomes.isEmpty,
      summary.failedOutcomes.isEmpty,
      summary.collisionCount == 0,
      summary.errorMessage == nil
    {
      Label(
        MoaIMFLocalization.text("scanResult.noChanges"),
        systemImage: "checkmark.circle"
      )
      .foregroundStyle(.secondary)
    }

    if !summary.renamedOutcomes.isEmpty {
      OutcomeSection(
        title: MoaIMFLocalization.text("scanResult.changedFiles"),
        systemImage: "text.badge.checkmark",
        tint: .green,
        outcomes: summary.renamedOutcomes,
        showTarget: true
      )
    }

    if !summary.failedOutcomes.isEmpty {
      OutcomeSection(
        title: MoaIMFLocalization.text("scanResult.failedFiles"),
        systemImage: "xmark.circle",
        tint: .red,
        outcomes: summary.failedOutcomes,
        showTarget: false
      )
    }

    if summary.collisionCount > 0 {
      Label(
        String(
          format: MoaIMFLocalization.text("scanResult.collisions"),
          summary.collisionCount
        ),
        systemImage: "arrow.triangle.merge"
      )
      .foregroundStyle(.orange)
    }

    if summary.deferredCount > 0 {
      Label(
        String(
          format: MoaIMFLocalization.text("scanResult.deferred"),
          summary.deferredCount
        ),
        systemImage: "clock"
      )
      .foregroundStyle(.secondary)
    }
  }

  private var summaryText: String {
    String(
      format: MoaIMFLocalization.text("scanResult.summary"),
      summary.scannedCount,
      summary.candidateCount,
      summary.renamedCount,
      summary.collisionCount,
      summary.failedCount,
      summary.deferredCount
    )
  }

  private var hasProblems: Bool {
    summary.errorMessage != nil
      || summary.collisionCount > 0
      || summary.failedCount > 0
      || summary.deferredCount > 0
  }
}

private struct OutcomeSection: View {
  let title: String
  let systemImage: String
  let tint: Color
  let outcomes: [RenameOutcome]
  let showTarget: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Label(title, systemImage: systemImage)
        .font(.headline)
        .foregroundStyle(tint)

      VStack(alignment: .leading, spacing: 6) {
        ForEach(outcomes, id: \.identity) { outcome in
          OutcomeRow(outcome: outcome, showTarget: showTarget)
        }
      }
      .padding(.leading, 4)
    }
  }
}

private struct OutcomeRow: View {
  let outcome: RenameOutcome
  let showTarget: Bool

  private var sourceName: String {
    ScanResultFileNameFormatter.sourceName(for: outcome)
  }

  private var targetName: String {
    ScanResultFileNameFormatter.targetName(for: outcome)
  }

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: showTarget ? "checkmark" : "xmark")
        .font(.caption.weight(.semibold))
        .foregroundStyle(showTarget ? .green : .red)
        .frame(width: 14)

      VStack(alignment: .leading, spacing: 2) {
        if showTarget {
          ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
              Text(sourceName)
                .lineLimit(1)
                .truncationMode(.middle)
              Text("→")
                .foregroundStyle(.secondary)
              Text(targetName)
                .lineLimit(1)
                .truncationMode(.middle)
            }

            VStack(alignment: .leading, spacing: 2) {
              Text(sourceName)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
              HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("→")
                  .foregroundStyle(.secondary)
                Text(targetName)
                  .lineLimit(2)
                  .truncationMode(.middle)
              }
            }
          }
        } else {
          Text(outcome.source.lastPathComponent)
          Text(outcome.reason ?? outcome.kind.rawValue)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .textSelection(.enabled)
      .lineLimit(2)
    }
    .font(.callout)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

enum ScanResultFileNameFormatter {
  static func sourceName(for outcome: RenameOutcome) -> String {
    let sourceName = outcome.source.lastPathComponent
    let targetName = targetName(for: outcome)
    if sourceName.utf8.elementsEqual(targetName.utf8) {
      return readableHangulJamo(of: targetName)
    }
    return compatibilityJamoOnly(of: sourceName)
  }

  static func targetName(for outcome: RenameOutcome) -> String {
    UnicodeNormalizer.nfc(outcome.target.lastPathComponent)
  }

  private static func compatibilityJamoOnly(of name: String) -> String {
    name.unicodeScalars
      .map { compatibilityJamo[$0.value] ?? String($0) }
      .joined()
  }

  private static func readableHangulJamo(of name: String) -> String {
    name.unicodeScalars
      .map { scalar in
        hangulSyllableJamo(scalar.value) ?? compatibilityJamo[scalar.value] ?? String(scalar)
      }
      .joined()
  }

  private static func hangulSyllableJamo(_ value: UInt32) -> String? {
    guard (0xAC00...0xD7A3).contains(value) else { return nil }

    let syllableIndex = value - 0xAC00
    let leadingIndex = Int(syllableIndex / (21 * 28))
    let vowelIndex = Int((syllableIndex % (21 * 28)) / 28)
    let trailingIndex = Int(syllableIndex % 28)

    var jamo = [
      leadingCompatibilityJamo[leadingIndex],
      vowelCompatibilityJamo[vowelIndex],
    ]
    if trailingIndex > 0 {
      jamo.append(trailingCompatibilityJamo[trailingIndex])
    }
    return jamo.joined()
  }

  private static let leadingCompatibilityJamo = [
    "ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
  ]

  private static let vowelCompatibilityJamo = [
    "ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ", "ㅚ", "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ",
    "ㅢ", "ㅣ",
  ]

  private static let trailingCompatibilityJamo = [
    "", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ",
    "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ",
  ]

  private static let compatibilityJamo: [UInt32: String] = [
    0x1100: "ㄱ", 0x1101: "ㄲ", 0x1102: "ㄴ", 0x1103: "ㄷ", 0x1104: "ㄸ",
    0x1105: "ㄹ", 0x1106: "ㅁ", 0x1107: "ㅂ", 0x1108: "ㅃ", 0x1109: "ㅅ",
    0x110A: "ㅆ", 0x110B: "ㅇ", 0x110C: "ㅈ", 0x110D: "ㅉ", 0x110E: "ㅊ",
    0x110F: "ㅋ", 0x1110: "ㅌ", 0x1111: "ㅍ", 0x1112: "ㅎ",
    0x1161: "ㅏ", 0x1162: "ㅐ", 0x1163: "ㅑ", 0x1164: "ㅒ", 0x1165: "ㅓ",
    0x1166: "ㅔ", 0x1167: "ㅕ", 0x1168: "ㅖ", 0x1169: "ㅗ", 0x116A: "ㅘ",
    0x116B: "ㅙ", 0x116C: "ㅚ", 0x116D: "ㅛ", 0x116E: "ㅜ", 0x116F: "ㅝ",
    0x1170: "ㅞ", 0x1171: "ㅟ", 0x1172: "ㅠ", 0x1173: "ㅡ", 0x1174: "ㅢ",
    0x1175: "ㅣ",
    0x11A8: "ㄱ", 0x11A9: "ㄲ", 0x11AA: "ㄳ", 0x11AB: "ㄴ", 0x11AC: "ㄵ",
    0x11AD: "ㄶ", 0x11AE: "ㄷ", 0x11AF: "ㄹ", 0x11B0: "ㄺ", 0x11B1: "ㄻ",
    0x11B2: "ㄼ", 0x11B3: "ㄽ", 0x11B4: "ㄾ", 0x11B5: "ㄿ", 0x11B6: "ㅀ",
    0x11B7: "ㅁ", 0x11B8: "ㅂ", 0x11B9: "ㅄ", 0x11BA: "ㅅ", 0x11BB: "ㅆ",
    0x11BC: "ㅇ", 0x11BD: "ㅈ", 0x11BE: "ㅊ", 0x11BF: "ㅋ", 0x11C0: "ㅌ",
    0x11C1: "ㅍ", 0x11C2: "ㅎ",
  ]
}
