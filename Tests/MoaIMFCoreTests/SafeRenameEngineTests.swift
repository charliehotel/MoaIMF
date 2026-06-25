import Foundation
import XCTest

@testable import MoaIMFCore

final class SafeRenameEngineTests: XCTestCase {
  func testRenamesRawEntryToNFCAndPreservesContentsAndExtendedAttributes() async throws {
    let fixture = try RenameFixture()
    defer { fixture.remove() }
    let source = try fixture.write(name: "가합.txt", contents: "payload")
    try setExtendedAttribute(name: "com.charliehotel.MoaIMF.test", value: "kept", at: source)
    let candidate = try fixture.candidate(rawName: "가합.txt")
    let engine = SafeRenameEngine(journal: fixture.journal)

    let outcomes = try await engine.apply(plan(candidates: [candidate]))

    XCTAssertEqual(outcomes.map(\.kind), [.renamed], "\(outcomes)")
    XCTAssertEqual(try fixture.rawNames(), ["가합.txt"])
    XCTAssertEqual(try String(contentsOf: fixture.root.appendingPathComponent("가합.txt")), "payload")
    XCTAssertEqual(
      try extendedAttribute(
        name: "com.charliehotel.MoaIMF.test", at: fixture.root.appendingPathComponent("가합.txt")),
      "kept"
    )
    XCTAssertEqual(try fixture.rawNames().first.map(UnicodeNormalizer.isNFC), true)
  }

  func testCollisionParticipantIsNotMutated() async throws {
    let fixture = try RenameFixture()
    defer { fixture.remove() }
    try fixture.write(name: "가.txt", contents: "payload")
    let candidate = try fixture.candidate(rawName: "가.txt")
    let collision = NormalizationCollision(
      parent: fixture.root,
      normalizedKey: "가.txt",
      rawNames: ["가.txt", "가.txt"]
    )
    let engine = SafeRenameEngine(journal: fixture.journal)

    let outcomes = try await engine.apply(
      NormalizationPlan(candidates: [candidate], collisions: [collision])
    )

    XCTAssertEqual(outcomes.map(\.kind), [.failed])
    XCTAssertEqual(try fixture.rawNames(), ["가.txt"])
  }

  func testRenamesNestedEntriesDeepestFirst() async throws {
    let fixture = try RenameFixture()
    defer { fixture.remove() }
    let parent = fixture.root.appendingPathComponent("부모", isDirectory: true)
    try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
    try Data("child".utf8).write(to: parent.appendingPathComponent("자식.txt"))
    let snapshot = try FileTreeScanner().scan(root: fixture.root)
    let candidates = snapshot.entries.filter { !UnicodeNormalizer.isNFC($0.rawName) }.map {
      RenameCandidate(
        identity: $0.identity,
        source: $0.url,
        targetName: UnicodeNormalizer.nfc($0.rawName)
      )
    }
    let engine = SafeRenameEngine(journal: fixture.journal)

    let outcomes = try await engine.apply(plan(candidates: candidates))

    XCTAssertEqual(outcomes.map(\.kind), [.renamed, .renamed], "\(outcomes)")
    let finalFile = fixture.root.appendingPathComponent("부모/자식.txt")
    XCTAssertEqual(try String(contentsOf: finalFile), "child")
  }

  func testPostVerificationFailureRollsBackAndMarksVolumeUnsupported() async throws {
    let fixture = try RenameFixture()
    defer { fixture.remove() }
    try fixture.write(name: "가.txt", contents: "payload")
    let candidate = try fixture.candidate(rawName: "가.txt")
    let hooks = RenameEngineHooks(verificationOverride: { _, _ in false })
    let engine = SafeRenameEngine(journal: fixture.journal, hooks: hooks)

    let outcomes = try await engine.apply(plan(candidates: [candidate]))
    let isUnsupported = await engine.isVolumeUnsupported(candidate.identity.volume)

    XCTAssertEqual(outcomes.map(\.kind), [.rolledBack], "\(outcomes)")
    XCTAssertTrue(isUnsupported)
    XCTAssertEqual(try fixture.rawNames(), ["가.txt"])
  }

  func testDirectFailureUsesTemporarySiblingAndLeavesNoJournal() async throws {
    let fixture = try RenameFixture()
    defer { fixture.remove() }
    try fixture.write(name: "가.txt", contents: "payload")
    let candidate = try fixture.candidate(rawName: "가.txt")
    let hooks = RenameEngineHooks(directMove: { _, _ in throw InjectedRenameFailure.expected })
    let engine = SafeRenameEngine(journal: fixture.journal, hooks: hooks)

    let outcomes = try await engine.apply(plan(candidates: [candidate]))
    let journalRecords = try await fixture.journal.activeRecords()
    let storedNames = try fixture.rawNames()

    XCTAssertEqual(outcomes.map(\.kind), [.renamed], "\(outcomes), journal: \(journalRecords)")
    XCTAssertEqual(storedNames, ["가.txt"])
    XCTAssertEqual(
      storedNames.first.map(UnicodeNormalizer.isNFC),
      true,
      "stored UTF-8: \(storedNames.map { Array($0.utf8) })"
    )
    XCTAssertTrue(journalRecords.isEmpty)
    XCTAssertFalse(try fixture.rawNames().contains { $0.hasPrefix(".moaimf-") })
  }

  func testFailureAfterTemporaryMoveRestoresOriginalName() async throws {
    let fixture = try RenameFixture()
    defer { fixture.remove() }
    try fixture.write(name: "가.txt", contents: "payload")
    let candidate = try fixture.candidate(rawName: "가.txt")
    let hooks = RenameEngineHooks(
      directMove: { _, _ in throw InjectedRenameFailure.expected },
      afterTemporaryMove: { throw InjectedRenameFailure.expected }
    )
    let engine = SafeRenameEngine(journal: fixture.journal, hooks: hooks)

    let outcomes = try await engine.apply(plan(candidates: [candidate]))
    let journalRecords = try await fixture.journal.activeRecords()

    XCTAssertEqual(outcomes.map(\.kind), [.rolledBack])
    XCTAssertEqual(try fixture.rawNames(), ["가.txt"])
    XCTAssertTrue(journalRecords.isEmpty)
  }

  func testCancellationStopsBeforeNextCandidate() async throws {
    let fixture = try RenameFixture()
    defer { fixture.remove() }
    try fixture.write(name: "가.txt", contents: "first")
    try fixture.write(name: "나.txt", contents: "second")
    let candidates = try [fixture.candidate(rawName: "가.txt"), fixture.candidate(rawName: "나.txt")]
    let gate = CandidateGate()
    let hooks = RenameEngineHooks(afterCandidate: { await gate.arriveAndWait() })
    let engine = SafeRenameEngine(journal: fixture.journal, hooks: hooks)
    let normalizationPlan = plan(candidates: candidates)
    let task = Task { try await engine.apply(normalizationPlan) }

    await gate.waitUntilArrived()
    task.cancel()
    await gate.release()

    do {
      _ = try await task.value
      XCTFail("Expected cancellation")
    } catch is CancellationError {
      let journalRecords = try await fixture.journal.activeRecords()
      XCTAssertEqual(try fixture.rawNames().filter(UnicodeNormalizer.isNFC).count, 1)
      XCTAssertTrue(journalRecords.isEmpty)
    }
  }

  func testStartupRecoveryRestoresTemporaryEntry() async throws {
    let fixture = try RenameFixture()
    defer { fixture.remove() }
    let source = try fixture.write(name: "가.txt", contents: "payload")
    let candidate = try fixture.candidate(rawName: "가.txt")
    let operationID = UUID()
    let temporary = fixture.root.appendingPathComponent(
      ".moaimf-\(operationID.uuidString)-temporary")
    let target = fixture.root.appendingPathComponent("가.txt")
    try FileManager.default.moveItem(at: source, to: temporary)
    try await fixture.journal.write(
      RenameRecoveryRecord(
        operationID: operationID,
        identity: candidate.identity,
        originalURL: source,
        temporaryURL: temporary,
        targetURL: target,
        targetName: "가.txt",
        phase: .temporary
      )
    )
    let engine = SafeRenameEngine(journal: fixture.journal)

    let outcomes = try await engine.recoverPendingOperations()
    let journalRecords = try await fixture.journal.activeRecords()

    XCTAssertEqual(outcomes.map(\.kind), [.rolledBack])
    XCTAssertEqual(try fixture.rawNames(), ["가.txt"])
    XCTAssertTrue(journalRecords.isEmpty)
  }

  private func plan(candidates: [RenameCandidate]) -> NormalizationPlan {
    NormalizationPlan(candidates: candidates, collisions: [])
  }
}
