import Darwin
import Foundation
import XCTest

@testable import MoaIMFCore

final class NormalizationWorkflowTests: XCTestCase {
  func testPreviewApplyRulesPackagesAndSymlinksEndToEnd() async throws {
    let fixture = try WorkflowFixture()
    defer { fixture.remove() }
    let normalName = "완료.txt"
    let ariaName = "보류.aria2"
    let exactName = "정지"
    let globName = "글.download-1"
    let builtInName = "받는중.crdownload"
    let normalURL = try fixture.write(name: normalName, contents: "payload")
    try setWorkflowXattr(at: normalURL)
    _ = try fixture.write(name: ariaName, contents: "aria")
    _ = try fixture.write(name: exactName, contents: "exact")
    _ = try fixture.write(name: globName, contents: "glob")
    _ = try fixture.write(name: builtInName, contents: "download")
    try fixture.createBoundaries()
    let suffixRule = try await fixture.ruleStore.add(kind: .suffix, pattern: ".aria2")
    _ = try await fixture.ruleStore.add(kind: .exactName, pattern: exactName)
    _ = try await fixture.ruleStore.add(kind: .glob, pattern: "*.download-*")
    let service = fixture.makeService()

    let preview = try await service.scan(ScanRequest(root: fixture.root, scope: .manualPreview))

    XCTAssertEqual(preview.plan.candidates.map(\.source.lastPathComponent), [normalName])
    XCTAssertEqual(preview.summary.totalEntryCount, 7)
    XCTAssertEqual(preview.summary.nfcEntryCount, 2)
    XCTAssertEqual(preview.summary.nonNFCEntryCount, 5)
    XCTAssertEqual(preview.deferredIdentities.count, 4)

    let approved = Set(preview.plan.candidates.map(\.identity))
    let applied = try await service.scan(
      ScanRequest(root: fixture.root, scope: .manualApply(approved)))

    XCTAssertEqual(applied.outcomes.map(\.kind), [.renamed])
    XCTAssertTrue(try fixture.rawNames(in: fixture.root).contains("완료.txt"))
    XCTAssertEqual(
      try String(contentsOf: fixture.root.appendingPathComponent("완료.txt")),
      "payload"
    )
    XCTAssertEqual(try workflowXattr(at: fixture.root.appendingPathComponent("완료.txt")), "kept")
    XCTAssertTrue(try fixture.rawNames(in: fixture.package).contains("내부.txt"))
    XCTAssertTrue(try fixture.rawNames(in: fixture.outside).contains("외부.txt"))

    try await fixture.ruleStore.remove(id: suffixRule.id)
    let afterRemoval = try await service.scan(
      ScanRequest(root: fixture.root, scope: .manualPreview))
    let remainingCandidates = afterRemoval.plan.candidates.map(\.source.lastPathComponent)
    let reloadedRules = try await fixture.reloadedRuleStore().allRules()
    let recordedHistory = try await fixture.history.load().events

    XCTAssertEqual(remainingCandidates, [ariaName])
    XCTAssertEqual(reloadedRules.filter { $0.source == .user }.count, 2)
    XCTAssertEqual(recordedHistory.filter { $0.kind == .renamed }.count, 1)
  }

  func testAutomaticScanExcludesPreexistingBaselineButNormalizesNewItem() async throws {
    let fixture = try WorkflowFixture()
    defer { fixture.remove() }
    let oldName = "예전.txt"
    let newName = "새파일.txt"
    _ = try fixture.write(name: oldName, contents: "old")
    let service = fixture.makeService(quietPeriod: 0)
    let preview = try await service.scan(ScanRequest(root: fixture.root, scope: .manualPreview))
    let oldIdentity = try XCTUnwrap(
      preview.plan.candidates.first(where: { $0.source.lastPathComponent == oldName })?.identity)
    _ = try fixture.write(name: newName, contents: "new")

    let first = try await service.scan(
      ScanRequest(
        root: fixture.root,
        scope: .full,
        excludedIdentities: [oldIdentity]
      ))
    _ = try await service.scan(
      ScanRequest(root: fixture.root, scope: .candidates(first.pendingIdentities)))

    let names = try fixture.rawNames(in: fixture.root)
    XCTAssertTrue(names.contains(oldName))
    XCTAssertTrue(names.contains("새파일.txt"))
    XCTAssertFalse(first.pendingIdentities.contains(oldIdentity))
  }

  func testPathScanOnlySchedulesPendingItemsInsideEventPaths() async throws {
    let fixture = try WorkflowFixture()
    defer { fixture.remove() }
    let outsideName = "기존.txt"
    let eventName = "새파일.txt"
    _ = try fixture.write(name: outsideName, contents: "outside")
    let eventURL = try fixture.write(name: eventName, contents: "event")
    let service = fixture.makeService(quietPeriod: 0)
    let snapshot = try FileTreeScanner().scan(root: fixture.root)

    XCTAssertTrue(
      snapshot.entries.contains {
        $0.url.resolvingSymlinksInPath().path.precomposedStringWithCanonicalMapping
          == eventURL.resolvingSymlinksInPath().path.precomposedStringWithCanonicalMapping
      },
      "event=\(eventURL.path), entries=\(snapshot.entries.map(\.url.path))"
    )

    let first = try await service.scan(
      ScanRequest(root: fixture.root, scope: .paths([eventURL])))
    _ = try await service.scan(
      ScanRequest(root: fixture.root, scope: .candidates(first.pendingIdentities)))

    let names = try fixture.rawNames(in: fixture.root)
    XCTAssertEqual(first.pendingIdentities.count, 1)
    XCTAssertTrue(names.contains(outsideName))
    XCTAssertTrue(names.contains("새파일.txt"))
  }

  func testAutomaticScanDefersDirectoryContainingExcludedDescendant() async throws {
    let fixture = try WorkflowFixture()
    defer { fixture.remove() }
    let directoryName = "대기"
    let childName = "Working Copy"
    let directory = fixture.root.appendingPathComponent(directoryName, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("partial".utf8).write(to: directory.appendingPathComponent(childName))
    _ = try await fixture.ruleStore.add(kind: .exactName, pattern: childName)
    let service = fixture.makeService(quietPeriod: 0)

    let first = try await service.scan(ScanRequest(root: fixture.root, scope: .paths([directory])))
    let second = try await service.scan(
      ScanRequest(root: fixture.root, scope: .candidates(first.pendingIdentities)))

    let names = try fixture.rawNames(in: fixture.root)
    let message = [
      "names=\(names)",
      "firstDeferred=\(first.deferredIdentities.count)",
      "firstPending=\(first.pendingIdentities.count)",
      "outcomes=\(second.outcomes)",
    ].joined(separator: ", ")
    XCTAssertTrue(names.containsRawBytes(directoryName), message)
    XCTAssertFalse(names.containsRawBytes("대기"), message)
    XCTAssertTrue(second.outcomes.isEmpty, message)
  }
}

extension [String] {
  fileprivate func containsRawBytes(_ expected: String) -> Bool {
    let expectedBytes = Swift.Array<UInt8>(expected.utf8)
    return contains { Swift.Array<UInt8>($0.utf8) == expectedBytes }
  }
}

private final class WorkflowFixture {
  let container: URL
  let root: URL
  let outside: URL
  let package: URL
  let state: URL
  let ruleStore: StabilityRuleStore
  let history: HistoryStore

  init() throws {
    container = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    root = container.appendingPathComponent("watched", isDirectory: true)
    outside = container.appendingPathComponent("outside", isDirectory: true)
    package = root.appendingPathComponent("Fixture.app", isDirectory: true)
    state = container.appendingPathComponent("state", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: state, withIntermediateDirectories: true)
    ruleStore = StabilityRuleStore(fileURL: state.appendingPathComponent("rules.json"))
    history = HistoryStore(fileURL: state.appendingPathComponent("history.jsonl"))
  }

  func makeService(quietPeriod: TimeInterval = 30) -> NormalizationScanService {
    NormalizationScanService(
      ruleStore: ruleStore,
      tracker: StabilityTracker(quietPeriod: quietPeriod),
      engine: SafeRenameEngine(
        journal: RecoveryJournal(directory: state.appendingPathComponent("recovery"))),
      history: history,
      excludedRoots: [state]
    )
  }

  func reloadedRuleStore() -> StabilityRuleStore {
    StabilityRuleStore(fileURL: state.appendingPathComponent("rules.json"))
  }

  @discardableResult
  func write(name: String, contents: String) throws -> URL {
    let url = root.appendingPathComponent(name)
    try Data(contents.utf8).write(to: url)
    return url
  }

  func createBoundaries() throws {
    try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
    try Data("package".utf8).write(to: package.appendingPathComponent("내부.txt"))
    try Data("outside".utf8).write(to: outside.appendingPathComponent("외부.txt"))
    try FileManager.default.createSymbolicLink(
      at: root.appendingPathComponent("outside-link"),
      withDestinationURL: outside
    )
  }

  func rawNames(in directory: URL) throws -> [String] {
    try directory.withUnsafeFileSystemRepresentation { path in
      guard let path, let stream = Darwin.opendir(path) else { throw POSIXError(.EIO) }
      defer { Darwin.closedir(stream) }
      var names: [String] = []
      while let entry = Darwin.readdir(stream) {
        let length = Int(entry.pointee.d_namlen)
        let bytes = withUnsafeBytes(of: &entry.pointee.d_name) { Array($0.prefix(length)) }
        let name = String(decoding: bytes, as: UTF8.self)
        if name != "." && name != ".." { names.append(name) }
      }
      return names
    }
  }

  func remove() { try? FileManager.default.removeItem(at: container) }
}

private func setWorkflowXattr(at url: URL) throws {
  let bytes = Array("kept".utf8)
  let result = try url.withUnsafeFileSystemRepresentation { path in
    guard let path else { throw POSIXError(.EINVAL) }
    return bytes.withUnsafeBytes {
      Darwin.setxattr(path, "com.charliehotel.MoaIMF.workflow", $0.baseAddress, $0.count, 0, 0)
    }
  }
  guard result == 0 else { throw POSIXError(.EIO) }
}

private func workflowXattr(at url: URL) throws -> String {
  try url.withUnsafeFileSystemRepresentation { path in
    guard let path else { throw POSIXError(.EINVAL) }
    let size = Darwin.getxattr(path, "com.charliehotel.MoaIMF.workflow", nil, 0, 0, 0)
    guard size >= 0 else { throw POSIXError(.EIO) }
    var bytes = [UInt8](repeating: 0, count: size)
    let read = Darwin.getxattr(path, "com.charliehotel.MoaIMF.workflow", &bytes, size, 0, 0)
    guard read >= 0 else { throw POSIXError(.EIO) }
    return String(decoding: bytes.prefix(read), as: UTF8.self)
  }
}
