import Foundation
import XCTest

@testable import MoaIMFCore

final class StabilityTrackerTests: XCTestCase {
  func testBecomesStableAfterThirtyUnchangedSeconds() async {
    let tracker = StabilityTracker(quietPeriod: 30)
    let entry = makeEntry(name: "file.txt")
    let start = Date(timeIntervalSince1970: 1_000)

    let first = await tracker.observe(entry, at: start)
    let beforeQuietPeriod = await tracker.observe(entry, at: start.addingTimeInterval(29))
    let afterQuietPeriod = await tracker.observe(entry, at: start.addingTimeInterval(30))

    XCTAssertFalse(first)
    XCTAssertFalse(beforeQuietPeriod)
    XCTAssertTrue(afterQuietPeriod)
  }

  func testFingerprintChangesResetQuietPeriod() async {
    let tracker = StabilityTracker(quietPeriod: 30)
    let start = Date(timeIntervalSince1970: 1_000)
    let original = makeEntry(name: "file.txt", byteSize: 1, modifiedAt: start)
    let larger = makeEntry(name: "file.txt", byteSize: 2, modifiedAt: start)
    let modified = makeEntry(name: "file.txt", byteSize: 2, modifiedAt: start.addingTimeInterval(1))

    let first = await tracker.observe(original, at: start)
    let afterSizeChange = await tracker.observe(larger, at: start.addingTimeInterval(30))
    let afterDateChange = await tracker.observe(modified, at: start.addingTimeInterval(60))
    let afterQuietPeriod = await tracker.observe(modified, at: start.addingTimeInterval(90))

    XCTAssertFalse(first)
    XCTAssertFalse(afterSizeChange)
    XCTAssertFalse(afterDateChange)
    XCTAssertTrue(afterQuietPeriod)
  }

  func testReplacementIdentityStartsNewObservation() async {
    let tracker = StabilityTracker(quietPeriod: 30)
    let start = Date(timeIntervalSince1970: 1_000)
    let original = makeEntry(name: "file.txt", resource: "one")
    let replacement = makeEntry(name: "file.txt", resource: "two")

    let first = await tracker.observe(original, at: start)
    let afterReplacement = await tracker.observe(replacement, at: start.addingTimeInterval(30))

    XCTAssertFalse(first)
    XCTAssertFalse(afterReplacement)
  }

  func testExcludedEntryNeverBecomesStable() async {
    let tracker = StabilityTracker(quietPeriod: 30)
    let start = Date(timeIntervalSince1970: 1_000)
    let exclusion = StabilityExclusionMatch(ruleID: "builtin.tmp", pattern: ".tmp")
    let entry = makeEntry(name: "file.tmp", exclusion: exclusion)

    let first = await tracker.observe(entry, at: start)
    let later = await tracker.observe(entry, at: start.addingTimeInterval(300))

    XCTAssertFalse(first)
    XCTAssertFalse(later)
  }

  func testDirectoryWaitsForExcludedDescendantAndRuleRemoval() async {
    let tracker = StabilityTracker(quietPeriod: 30)
    let start = Date(timeIntervalSince1970: 1_000)
    let directory = makeEntry(name: "folder", resource: "folder", isDirectory: true, depth: 1)
    let exclusion = StabilityExclusionMatch(ruleID: "user.tmp", pattern: ".tmp")
    let excludedChild = makeEntry(
      name: "folder/file.tmp",
      resource: "child",
      depth: 2,
      exclusion: exclusion
    )
    let includedChild = makeEntry(name: "folder/file.tmp", resource: "child", depth: 2)

    _ = await tracker.stableEntries(in: snapshot([directory, excludedChild]), at: start)
    let whileExcluded = await tracker.stableEntries(
      in: snapshot([directory, excludedChild]),
      at: start.addingTimeInterval(30)
    )
    let afterRemoval = await tracker.stableEntries(
      in: snapshot([directory, includedChild]),
      at: start.addingTimeInterval(31)
    )
    let afterQuietPeriod = await tracker.stableEntries(
      in: snapshot([directory, includedChild]),
      at: start.addingTimeInterval(61)
    )

    XCTAssertFalse(whileExcluded.contains { $0.identity == directory.identity })
    XCTAssertFalse(afterRemoval.contains { $0.identity == directory.identity })
    XCTAssertTrue(afterQuietPeriod.contains { $0.identity == directory.identity })
  }

  func testLatestSnapshotRemovesAbsentIdentities() async {
    let tracker = StabilityTracker(quietPeriod: 30)
    let entry = makeEntry(name: "file.txt")

    _ = await tracker.stableEntries(in: snapshot([entry]), at: .distantPast)
    _ = await tracker.stableEntries(in: snapshot([]), at: .distantFuture)
    let count = await tracker.trackedIdentityCount()

    XCTAssertEqual(count, 0)
  }

  private func makeEntry(
    name: String,
    resource: String = "resource",
    byteSize: Int64 = 1,
    modifiedAt: Date = Date(timeIntervalSince1970: 500),
    isDirectory: Bool = false,
    depth: Int = 1,
    exclusion: StabilityExclusionMatch? = nil
  ) -> ScannedEntry {
    ScannedEntry(
      identity: FileIdentity(volume: "volume", resource: resource),
      url: URL(fileURLWithPath: "/root").appendingPathComponent(name, isDirectory: isDirectory),
      rawName: URL(fileURLWithPath: name).lastPathComponent,
      depth: depth,
      isDirectory: isDirectory,
      isSymbolicLink: false,
      isPackage: false,
      byteSize: byteSize,
      modifiedAt: modifiedAt,
      stabilityExclusion: exclusion
    )
  }

  private func snapshot(_ entries: [ScannedEntry]) -> ScanSnapshot {
    ScanSnapshot(
      root: URL(fileURLWithPath: "/root", isDirectory: true),
      caseSensitive: true,
      entries: entries
    )
  }
}
