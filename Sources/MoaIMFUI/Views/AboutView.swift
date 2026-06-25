import SwiftUI

public struct AboutAppInfo: Equatable, Sendable {
  public let appName: String
  public let version: String
  public let build: String
  public let copyright: String

  public init(appName: String, version: String, build: String, copyright: String) {
    self.appName = appName
    self.version = version
    self.build = build
    self.copyright = copyright
  }

  public static func current(bundle: Bundle = .main) -> AboutAppInfo {
    let info = bundle.infoDictionary ?? [:]
    return AboutAppInfo(
      appName: info["CFBundleDisplayName"] as? String
        ?? info["CFBundleName"] as? String
        ?? MoaIMFLocalization.text("app.name"),
      version: info["CFBundleShortVersionString"] as? String ?? "0.1.0",
      build: info["CFBundleVersion"] as? String ?? "1",
      copyright: info["NSHumanReadableCopyright"] as? String ?? "Copyright © 2026 copylawbot"
    )
  }

  public var versionText: String {
    String(format: MoaIMFLocalization.text("about.version"), version, build)
  }
}

public struct AboutView: View {
  private let info: AboutAppInfo
  @ObservedObject private var languageManager: LanguageManager

  public init(
    info: AboutAppInfo = .current(),
    languageManager: LanguageManager = .shared
  ) {
    self.info = info
    self.languageManager = languageManager
  }

  public var body: some View {
    let _ = languageManager.selection

    VStack(alignment: .center, spacing: 12) {
      AboutCompositionMark()

      VStack(spacing: 4) {
        Text(info.appName)
          .font(.title2.weight(.semibold))
        Text(info.versionText)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      Text(MoaIMFLocalization.text("about.description"))
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)

      Text(MoaIMFLocalization.text("about.tagline"))
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)

      Text(info.copyright)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .padding(24)
    .frame(width: 420)
  }
}

private struct AboutCompositionMark: View {
  var body: some View {
    Text("ㅎㅏㄴ → 한")
      .font(.system(size: 19, weight: .semibold, design: .rounded))
      .monospacedDigit()
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .minimumScaleFactor(0.75)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .overlay {
        RoundedRectangle(cornerRadius: 8)
          .stroke(.secondary, lineWidth: 4)
      }
      .accessibilityLabel("ㅎㅏㄴ → 한")
      .accessibilityHint(MoaIMFLocalization.text("about.tagline"))
  }
}
