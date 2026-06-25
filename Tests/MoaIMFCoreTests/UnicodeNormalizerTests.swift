import XCTest

@testable import MoaIMFCore

final class UnicodeNormalizerTests: XCTestCase {
  func testNFCComposesDecomposedHangul() {
    let decomposed = "\u{1100}\u{1161}\u{1112}\u{1161}\u{11B8}"

    XCTAssertEqual(UnicodeNormalizer.nfc(decomposed), "가합")
    XCTAssertFalse(UnicodeNormalizer.isNFC(decomposed))
    XCTAssertTrue(UnicodeNormalizer.isNFC("가합"))
  }
}
