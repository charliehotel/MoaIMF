import XCTest

@testable import MoaIMFUI

final class LocalizationTests: XCTestCase {
  func testManualLanguageResourcesContainEveryInitialKey() throws {
    for language in MoaIMFLanguage.allCases where language != .system {
      let bundle = try XCTUnwrap(MoaIMFLocalization.bundle(for: language))
      for key in MoaIMFLocalization.initialKeys {
        XCTAssertNotEqual(
          bundle.localizedString(forKey: key, value: nil, table: nil), key,
          "Missing \(language.rawValue) localization for \(key)"
        )
      }
    }
  }

  func testExplicitLanguageLookupUsesRequestedResource() {
    XCTAssertEqual(
      MoaIMFLocalization.text("menu.pause", language: .english),
      "Pause Watching"
    )
    XCTAssertEqual(
      MoaIMFLocalization.text("menu.pause", language: .korean),
      "감시 일시정지"
    )
    XCTAssertEqual(
      MoaIMFLocalization.text("menu.pause", language: .japanese),
      "監視を一時停止"
    )
    XCTAssertEqual(
      MoaIMFLocalization.text("menu.pause", language: .simplifiedChinese),
      "暂停监视"
    )
  }

  @MainActor
  func testLanguageManagerAppliesAndPersistsManualSelection() {
    let preferences = LocalizationPreferences()
    let manager = LanguageManager(preferences: preferences)
    defer { MoaIMFLocalization.setLanguage(.system) }

    manager.setLanguage(.korean)
    XCTAssertEqual(preferences.language, .korean)
    XCTAssertEqual(MoaIMFLocalization.text("menu.about"), "MoaIMF에 관하여")

    manager.setLanguage(.english)
    XCTAssertEqual(preferences.language, .english)
    XCTAssertEqual(MoaIMFLocalization.text("menu.about"), "About MoaIMF")
  }

  @MainActor
  func testUserDefaultsPreferencesPersistLanguageSelection() {
    let suiteName = "MoaIMF.LocalizationTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let preferences = UserDefaultsAppPreferences(defaults: defaults)
    XCTAssertEqual(preferences.language, .system)

    preferences.language = .korean

    let restored = UserDefaultsAppPreferences(defaults: defaults)
    XCTAssertEqual(restored.language, .korean)
  }

  @MainActor
  func testUserDefaultsPreferencesPersistLaunchHintVisibility() {
    let suiteName = "MoaIMF.LaunchHintTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let preferences = UserDefaultsAppPreferences(defaults: defaults)
    XCTAssertFalse(preferences.isLaunchHintHidden)

    preferences.isLaunchHintHidden = true

    let restored = UserDefaultsAppPreferences(defaults: defaults)
    XCTAssertTrue(restored.isLaunchHintHidden)
  }
}

@MainActor
private final class LocalizationPreferences: AppPreferencesStoring {
  var isPaused = false
  var language: MoaIMFLanguage = .system
  var isLaunchHintHidden = false
}
