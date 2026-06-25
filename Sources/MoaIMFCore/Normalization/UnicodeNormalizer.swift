import Foundation

public enum UnicodeNormalizer: Sendable {
  public static func nfc(_ value: String) -> String {
    value.precomposedStringWithCanonicalMapping
  }

  public static func isNFC(_ value: String) -> Bool {
    value.utf8.elementsEqual(nfc(value).utf8)
  }
}
