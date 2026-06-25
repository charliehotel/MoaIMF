import Foundation
import XCTest

@testable import MoaIMFCore

final class HistoryStoreTests: XCTestCase {
  func testRecordsAndLoadsAllEventKinds() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.remove() }
    let store = HistoryStore(fileURL: fixture.fileURL, now: fixture.clock.now)
    let kinds: [HistoryEventKind] = [
      .renamed, .collision, .permission, .disconnected, .unsupportedFilesystem, .error,
    ]

    for kind in kinds {
      _ = try await store.record(
        kind: kind,
        rootIdentifier: "root",
        previousURL: URL(fileURLWithPath: "/before"),
        resultingURL: URL(fileURLWithPath: "/after"),
        reason: "reason"
      )
    }
    let result = try await store.load()

    XCTAssertEqual(result.events.map(\.kind), kinds)
    XCTAssertTrue(result.diagnostics.isEmpty)
    XCTAssertTrue(result.events.allSatisfy { $0.schemaVersion == 1 })
  }

  func testPrunesEventsOlderThanThirtyDaysWithoutTouchingRecoveryJournal() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.remove() }
    let recoveryFile = fixture.root.appendingPathComponent("recovery-record.json")
    let recoveryData = Data("recovery".utf8)
    try recoveryData.write(to: recoveryFile)
    let store = HistoryStore(fileURL: fixture.fileURL, now: fixture.clock.now)
    _ = try await store.record(
      kind: .renamed,
      rootIdentifier: "old",
      previousURL: nil,
      resultingURL: nil,
      reason: "old"
    )
    fixture.clock.advance(days: 31)

    _ = try await store.record(
      kind: .error,
      rootIdentifier: "new",
      previousURL: nil,
      resultingURL: nil,
      reason: "new"
    )
    let result = try await store.load()

    XCTAssertEqual(result.events.map(\.rootIdentifier), ["new"])
    XCTAssertEqual(try Data(contentsOf: recoveryFile), recoveryData)
  }

  func testMalformedLinesReturnTypedDiagnostics() async throws {
    let fixture = try HistoryFixture()
    defer { fixture.remove() }
    let store = HistoryStore(fileURL: fixture.fileURL, now: fixture.clock.now)
    _ = try await store.record(
      kind: .renamed,
      rootIdentifier: "root",
      previousURL: nil,
      resultingURL: nil,
      reason: "valid"
    )
    let handle = try FileHandle(forWritingTo: fixture.fileURL)
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("{malformed}\n".utf8))
    try handle.close()

    let result = try await store.load()

    XCTAssertEqual(result.events.count, 1)
    XCTAssertEqual(result.diagnostics.map(\.lineNumber), [2])
  }
}

private final class HistoryFixture {
  let root: URL
  let fileURL: URL
  let clock = TestClock(Date(timeIntervalSince1970: 1_000_000))

  init() throws {
    root = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    fileURL = root.appendingPathComponent("history.jsonl")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  func remove() {
    try? FileManager.default.removeItem(at: root)
  }
}

private final class TestClock: @unchecked Sendable {
  private let lock = NSLock()
  private var date: Date

  init(_ date: Date) {
    self.date = date
  }

  var now: @Sendable () -> Date {
    { [self] in lock.withLock { date } }
  }

  func advance(days: Double) {
    lock.withLock { date = date.addingTimeInterval(days * 24 * 60 * 60) }
  }
}
