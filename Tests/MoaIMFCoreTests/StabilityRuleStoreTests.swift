import Foundation
import XCTest

@testable import MoaIMFCore

final class StabilityRuleStoreTests: XCTestCase {
  func testBuiltInRulesAreLockedAndMatchKnownDownloadSuffixes() async throws {
    let fixture = try RuleStoreFixture()
    defer { fixture.remove() }
    let store = StabilityRuleStore(fileURL: fixture.fileURL)
    let rules = try await store.allRules()
    let matcher = StabilityExclusionMatcher(rules: rules)

    XCTAssertEqual(
      rules.filter { $0.source == .builtIn }.map(\.id),
      ["builtin.crdownload", "builtin.download", "builtin.part", "builtin.partial", "builtin.tmp"]
    )
    for suffix in [".crdownload", ".download", ".part", ".partial", ".tmp"] {
      XCTAssertNotNil(matcher.match(name: "filename\(suffix)", caseSensitive: true))
    }
    await assertThrowsErrorAsync(try await store.remove(id: "builtin.tmp")) { error in
      XCTAssertEqual(error as? StabilityRuleError, .builtInRule)
    }
  }

  func testCustomRulesMatchExactSuffixAndCharacterGlob() throws {
    let rules = [
      StabilityExclusionRule(id: "exact", kind: .exactName, pattern: "Working Copy", source: .user),
      StabilityExclusionRule(id: "suffix", kind: .suffix, pattern: ".aria2", source: .user),
      StabilityExclusionRule(id: "glob", kind: .glob, pattern: "*.download-?", source: .user),
    ]
    let matcher = StabilityExclusionMatcher(rules: rules)

    XCTAssertEqual(matcher.match(name: "Working Copy", caseSensitive: true)?.ruleID, "exact")
    XCTAssertEqual(matcher.match(name: "movie.aria2", caseSensitive: true)?.ruleID, "suffix")
    XCTAssertEqual(matcher.match(name: "a.download-한", caseSensitive: true)?.ruleID, "glob")
    XCTAssertEqual(matcher.match(name: "a.download-👨‍👩‍👧‍👦", caseSensitive: true)?.ruleID, "glob")
    XCTAssertNil(matcher.match(name: "a.download-AB", caseSensitive: true))
  }

  func testMatchingNormalizesNFCAndFollowsCasePolicy() {
    let matcher = StabilityExclusionMatcher(
      rules: [
        StabilityExclusionRule(id: "exact", kind: .exactName, pattern: "가.tmp", source: .user)
      ]
    )

    XCTAssertNotNil(matcher.match(name: "가.tmp", caseSensitive: true))
    XCTAssertNil(matcher.match(name: "가.TMP", caseSensitive: true))
    XCTAssertNotNil(matcher.match(name: "가.TMP", caseSensitive: false))
  }

  func testGlobTreatsOnlyStarAndQuestionMarkAsOperators() {
    let matcher = StabilityExclusionMatcher(
      rules: [
        StabilityExclusionRule(
          id: "literal",
          kind: .glob,
          pattern: "report[1].{tmp}\\draft",
          source: .user
        ),
        StabilityExclusionRule(id: "star", kind: .glob, pattern: "prefix*suffix", source: .user),
      ]
    )

    XCTAssertNotNil(matcher.match(name: "report[1].{tmp}\\draft", caseSensitive: true))
    XCTAssertNotNil(matcher.match(name: "prefixsuffix", caseSensitive: true))
    XCTAssertNotNil(matcher.match(name: "prefix-many-suffix", caseSensitive: true))
  }

  func testRejectsInvalidAndDuplicateRules() async throws {
    let fixture = try RuleStoreFixture()
    defer { fixture.remove() }
    let store = StabilityRuleStore(fileURL: fixture.fileURL)

    try await assertRuleError(.emptyPattern) { try await store.add(kind: .exactName, pattern: "") }
    try await assertRuleError(.patternTooLong) {
      try await store.add(kind: .glob, pattern: String(repeating: "a", count: 256))
    }
    try await assertRuleError(.pathSeparator) { try await store.add(kind: .glob, pattern: "a/b") }
    try await assertRuleError(.nulCharacter) { try await store.add(kind: .glob, pattern: "a\0b") }
    try await assertRuleError(.invalidSuffix) {
      try await store.add(kind: .suffix, pattern: "aria2")
    }
    try await assertRuleError(.wildcardsNotAllowed) {
      try await store.add(kind: .exactName, pattern: "Work*")
    }
    try await assertRuleError(.duplicateRule) {
      try await store.add(kind: .suffix, pattern: ".tmp")
    }
    _ = try await store.add(kind: .exactName, pattern: "가")
    try await assertRuleError(.duplicateRule) {
      try await store.add(kind: .exactName, pattern: "가")
    }
  }

  func testUserRulesPersistAndCanBeRemoved() async throws {
    let fixture = try RuleStoreFixture()
    defer { fixture.remove() }
    let firstStore = StabilityRuleStore(fileURL: fixture.fileURL)
    let added = try await firstStore.add(kind: .suffix, pattern: ".aria2")
    let reloadedStore = StabilityRuleStore(fileURL: fixture.fileURL)
    let reloadedRules = try await reloadedStore.allRules()

    XCTAssertTrue(reloadedRules.contains(added))
    try await reloadedStore.remove(id: added.id)
    let remainingRules = try await reloadedStore.allRules()
    XCTAssertFalse(remainingRules.contains(added))
  }

  private func assertRuleError(
    _ expected: StabilityRuleError,
    operation: () async throws -> StabilityExclusionRule
  ) async throws {
    do {
      _ = try await operation()
      XCTFail("Expected \(expected)")
    } catch {
      XCTAssertEqual(error as? StabilityRuleError, expected)
    }
  }
}

private struct RuleStoreFixture {
  let root: URL
  let fileURL: URL

  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    fileURL = root.appendingPathComponent("stability-rules.json")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  func remove() {
    try? FileManager.default.removeItem(at: root)
  }
}

private func assertThrowsErrorAsync<T>(
  _ expression: @autoclosure () async throws -> T,
  _ errorHandler: (Error) -> Void
) async {
  do {
    _ = try await expression()
    XCTFail("Expected error")
  } catch {
    errorHandler(error)
  }
}
