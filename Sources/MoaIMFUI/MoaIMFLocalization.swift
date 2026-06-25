import Combine
import Foundation

public enum MoaIMFLanguage: String, CaseIterable, Identifiable, Sendable {
  case system
  case english = "en"
  case korean = "ko"
  case japanese = "ja"
  case simplifiedChinese = "zh-Hans"
  case traditionalChinese = "zh-Hant"
  case vietnamese = "vi"
  case french = "fr"
  case german = "de"
  case spanish = "es"
  case portuguese = "pt"
  case thai = "th"
  case arabic = "ar"

  public var id: String { rawValue }

  var lprojIdentifier: String? {
    switch self {
    case .system: nil
    default: rawValue
    }
  }

  var localizationKey: String {
    switch self {
    case .system: "language.system"
    case .english: "language.en"
    case .korean: "language.ko"
    case .japanese: "language.ja"
    case .simplifiedChinese: "language.zhHans"
    case .traditionalChinese: "language.zhHant"
    case .vietnamese: "language.vi"
    case .french: "language.fr"
    case .german: "language.de"
    case .spanish: "language.es"
    case .portuguese: "language.pt"
    case .thai: "language.th"
    case .arabic: "language.ar"
    }
  }
}

@MainActor
public final class LanguageManager: ObservableObject {
  public static let shared = LanguageManager()

  @Published public private(set) var selection: MoaIMFLanguage

  private let preferences: any AppPreferencesStoring

  public init(preferences: any AppPreferencesStoring = UserDefaultsAppPreferences()) {
    self.preferences = preferences
    selection = preferences.language
    MoaIMFLocalization.setLanguage(selection)
  }

  public func setLanguage(_ language: MoaIMFLanguage) {
    guard selection != language else { return }
    preferences.language = language
    selection = language
    MoaIMFLocalization.setLanguage(language)
  }
}

public enum MoaIMFLocalization {
  public static let initialKeys = [
    "app.name", "status.watching", "status.scanning", "status.paused", "status.attention",
    "status.noFolders", "status.permissionRequired", "status.disconnected", "status.unsupported",
    "menu.about", "menu.pause", "menu.resume", "menu.scanAll", "menu.settings", "menu.history",
    "menu.loginAtLaunch", "menu.loginStatus.enabled", "menu.loginStatus.requiresApproval",
    "menu.loginStatus.disabled", "menu.loginStatus.notFound", "menu.loginOpenSettings",
    "menu.todayRenamedCount", "menu.language", "menu.quit",
    "language.system", "language.en", "language.ko", "language.ja", "language.zhHans",
    "language.zhHant", "language.vi", "language.fr", "language.de", "language.es",
    "language.pt", "language.th", "language.ar",
    "launchHint.title", "launchHint.body", "launchHint.dontShowAgain",
    "firstRun.title", "firstRun.body", "firstRun.chooseDownloads",
    "firstRun.normalizeExisting", "firstRun.watchNewOnly",
    "about.version", "about.description", "about.tagline",
    "folder.add", "folder.remove", "folder.scan", "folder.reselect", "folder.removeExplanation",
    "folder.scan.total", "folder.scan.nfc", "folder.scan.nfd", "folder.scan.actionable",
    "folder.scan.summary", "folder.scan.clean", "folder.scan.more",
    "stability.title", "stability.description", "stability.builtIn", "stability.custom",
    "stability.add", "stability.remove", "stability.kind.exactName", "stability.kind.suffix",
    "stability.kind.glob", "stability.invalid", "stability.matched", "history.empty",
    "history.emptySearch", "history.title", "history.resultSummary", "history.typeLabel",
    "history.searchPlaceholder",
    "alert.collision", "alert.permission", "alert.disconnected", "alert.unsupported",
    "alert.generic", "common.ok", "common.cancel", "filter.all", "history.filter.renamed",
    "history.filter.collision", "history.filter.permission", "history.filter.error",
    "history.scope.today", "history.scope.sevenDays", "history.scope.thirtyDays",
    "history.scope.all", "history.event.renamed", "history.event.collision",
    "history.event.permission", "history.event.disconnected", "history.event.unsupportedFilesystem",
  ]

  nonisolated(unsafe) private static var selectedLanguage: MoaIMFLanguage = .system

  public static func setLanguage(_ language: MoaIMFLanguage) {
    selectedLanguage = language
  }

  public static func text(_ key: String) -> String {
    selectedBundle?.localizedString(forKey: key, value: nil, table: nil) ?? key
  }

  public static func text(_ key: String, language: MoaIMFLanguage) -> String {
    bundle(for: language)?.localizedString(forKey: key, value: nil, table: nil) ?? key
  }

  public static func bundle(for language: String) -> Bundle? {
    let candidates = [language, language.lowercased()]
    guard
      let url = candidates.lazy.compactMap({ identifier in
        resourceBundle?.url(forResource: identifier, withExtension: "lproj")
      }).first
    else {
      return nil
    }
    return Bundle(url: url)
  }

  public static func bundle(for language: MoaIMFLanguage) -> Bundle? {
    guard let identifier = language.lprojIdentifier else {
      return resourceBundle
    }
    return bundle(for: identifier)
  }

  private static var selectedBundle: Bundle? {
    bundle(for: selectedLanguage)
  }

  private static let resourceBundle: Bundle? = {
    let bundleName = "MoaIMF_MoaIMFUI.bundle"
    if Bundle.main.bundleURL.pathExtension == "app" {
      guard let resourceURL = Bundle.main.resourceURL else { return nil }
      return Bundle(url: resourceURL.appendingPathComponent(bundleName))
    }
    return Bundle.module
  }()
}
