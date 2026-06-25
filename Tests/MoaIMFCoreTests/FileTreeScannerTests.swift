import Foundation
import XCTest

@testable import MoaIMFCore

final class FileTreeScannerTests: XCTestCase {
  func testScansEntriesWithoutCrossingPackageSymlinkOrExcludedBoundaries() throws {
    let fixture = try TemporaryScanFixture()
    defer { fixture.remove() }

    let snapshot = try FileTreeScanner(excludedRoots: fixture.excludedRoots).scan(
      root: fixture.root)
    let paths = relativePaths(in: snapshot)

    XCTAssertTrue(paths.contains("normal"))
    XCTAssertTrue(paths.contains(".hidden.txt"))
    XCTAssertTrue(paths.contains("Fixture.app"))
    XCTAssertFalse(paths.contains("Fixture.app/Contents/child.txt"))
    XCTAssertTrue(paths.contains("outside-link"))
    XCTAssertFalse(paths.contains("outside-link/outside.txt"))
    for excludedName in ["Application Support", "history", "recovery-journal"] {
      XCTAssertFalse(paths.contains(excludedName))
      XCTAssertFalse(paths.contains { $0.hasPrefix(excludedName + "/") })
    }
  }

  func testCapturesMetadataAndVolumeCaseSensitivity() throws {
    let fixture = try TemporaryScanFixture()
    defer { fixture.remove() }

    let snapshot = try FileTreeScanner().scan(root: fixture.root)
    let hidden = try XCTUnwrap(snapshot.entries.first { $0.rawName == ".hidden.txt" })
    let expectedCaseSensitivity = try fixture.root.resourceValues(
      forKeys: [.volumeSupportsCaseSensitiveNamesKey]
    ).volumeSupportsCaseSensitiveNames

    XCTAssertEqual(hidden.rawName, ".hidden.txt")
    XCTAssertEqual(hidden.depth, 1)
    XCTAssertFalse(hidden.isDirectory)
    XCTAssertFalse(hidden.isSymbolicLink)
    XCTAssertFalse(hidden.isPackage)
    XCTAssertEqual(hidden.byteSize, 6)
    XCTAssertGreaterThan(hidden.modifiedAt.timeIntervalSince1970, 0)
    XCTAssertFalse(hidden.identity.volume.isEmpty)
    XCTAssertFalse(hidden.identity.resource.isEmpty)
    XCTAssertEqual(snapshot.caseSensitive, expectedCaseSensitivity)
  }

  func testPreservesRawNFCNameFromDirectoryEntry() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let temporary = root.appendingPathComponent("temporary")
    try Data("value".utf8).write(to: temporary)
    try RenameFileSystem().moveExclusively(from: temporary, toParent: root, rawName: "가.txt")

    let snapshot = try FileTreeScanner().scan(root: root)
    let entry = try XCTUnwrap(snapshot.entries.first)

    XCTAssertEqual(Array(entry.rawName.utf8), Array("가.txt".utf8))
    XCTAssertTrue(UnicodeNormalizer.isNFC(entry.rawName))
  }

  func testMatchedDirectoryIsReportedWithoutTraversingDescendants() throws {
    let fixture = try TemporaryScanFixture()
    defer { fixture.remove() }
    try Data("child".utf8).write(to: fixture.normalDirectory.appendingPathComponent("child.txt"))
    let rule = StabilityExclusionRule(
      id: "user.normal",
      kind: .exactName,
      pattern: "normal",
      source: .user
    )
    let matcher = StabilityExclusionMatcher(rules: [rule])

    let snapshot = try FileTreeScanner().scan(root: fixture.root, matcher: matcher)
    let normal = try XCTUnwrap(snapshot.entries.first { $0.rawName == "normal" })

    XCTAssertEqual(normal.stabilityExclusion?.ruleID, "user.normal")
    XCTAssertFalse(snapshot.entries.contains { $0.url.path.hasSuffix("normal/child.txt") })
  }

  private func relativePaths(in snapshot: ScanSnapshot) -> Set<String> {
    let prefix = snapshot.root.path + "/"
    return Set(
      snapshot.entries.compactMap { entry in
        guard entry.url.path.hasPrefix(prefix) else { return nil }
        return String(entry.url.path.dropFirst(prefix.count))
      })
  }
}

private final class TemporaryScanFixture {
  let root: URL
  let outsideRoot: URL
  let normalDirectory: URL
  let hiddenFile: URL
  let package: URL
  let packageChild: URL
  let symlink: URL
  let outsideFile: URL
  let excludedRoots: [URL]

  init(fileManager: FileManager = .default) throws {
    let base = fileManager.temporaryDirectory.resolvingSymlinksInPath()
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    root = base.appendingPathComponent("root", isDirectory: true)
    outsideRoot = base.appendingPathComponent("outside", isDirectory: true)
    normalDirectory = root.appendingPathComponent("normal", isDirectory: true)
    hiddenFile = root.appendingPathComponent(".hidden.txt")
    package = root.appendingPathComponent("Fixture.app", isDirectory: true)
    packageChild = package.appendingPathComponent("Contents/child.txt")
    symlink = root.appendingPathComponent("outside-link", isDirectory: true)
    outsideFile = outsideRoot.appendingPathComponent("outside.txt")
    excludedRoots = [
      root.appendingPathComponent("Application Support", isDirectory: true),
      root.appendingPathComponent("history", isDirectory: true),
      root.appendingPathComponent("recovery-journal", isDirectory: true),
    ]

    try fileManager.createDirectory(at: normalDirectory, withIntermediateDirectories: true)
    try fileManager.createDirectory(
      at: packageChild.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try fileManager.createDirectory(at: outsideRoot, withIntermediateDirectories: true)
    try Data("hidden".utf8).write(to: hiddenFile)
    try Data("package".utf8).write(to: packageChild)
    try Data("outside".utf8).write(to: outsideFile)
    for excludedRoot in excludedRoots {
      try fileManager.createDirectory(at: excludedRoot, withIntermediateDirectories: true)
      try Data("state".utf8).write(to: excludedRoot.appendingPathComponent("state.json"))
    }
    try fileManager.createSymbolicLink(at: symlink, withDestinationURL: outsideRoot)
  }

  func remove(fileManager: FileManager = .default) {
    try? fileManager.removeItem(at: root.deletingLastPathComponent())
  }
}
