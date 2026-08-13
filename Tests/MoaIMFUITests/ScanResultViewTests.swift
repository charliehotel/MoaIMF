import MoaIMFCore
import XCTest

@testable import MoaIMFUI

final class ScanResultViewTests: XCTestCase {
  func testFormatsHangulNormalizationAsReadableBeforeAndAfterNames() {
    let source = URL(fileURLWithPath: "/tmp/테스트.txt")
    let target = URL(fileURLWithPath: "/tmp/테스트.txt")
    let outcome = RenameOutcome(
      identity: FileIdentity(volume: "volume", resource: "file"),
      source: source,
      target: target,
      kind: .renamed,
      reason: nil
    )

    XCTAssertEqual(
      Array(ScanResultFileNameFormatter.sourceName(for: outcome).utf8),
      Array("ㅌㅔㅅㅡㅌㅡ.txt".utf8)
    )
    XCTAssertEqual(
      Array(ScanResultFileNameFormatter.targetName(for: outcome).utf8),
      Array("테스트.txt".utf8)
    )
  }

  func testKeepsComposedHangulAndNonHangulTextInAnActualSourceName() {
    let source = URL(string: "file:///tmp/한글-보고서-café.txt")!
    let target = URL(string: "file:///tmp/한글-보고서-café.txt")!
    let outcome = RenameOutcome(
      identity: FileIdentity(volume: "volume", resource: "mixed"),
      source: source,
      target: target,
      kind: .renamed,
      reason: nil
    )

    XCTAssertEqual(
      Array(ScanResultFileNameFormatter.sourceName(for: outcome).utf8),
      Array("ㅎㅏㄴㄱㅡㄹ-보고서-café.txt".utf8)
    )
  }

  func testDecomposesHangulWhenSourceAndTargetHaveSameNormalizedBytes() {
    let source = URL(string: "file:///tmp/한글-café.txt")!
    let target = URL(string: "file:///tmp/한글-café.txt")!
    let outcome = RenameOutcome(
      identity: FileIdentity(volume: "volume", resource: "fallback"),
      source: source,
      target: target,
      kind: .renamed,
      reason: nil
    )

    XCTAssertEqual(
      Array(ScanResultFileNameFormatter.sourceName(for: outcome).utf8),
      Array("ㅎㅏㄴㄱㅡㄹ-café.txt".utf8)
    )
  }
}
