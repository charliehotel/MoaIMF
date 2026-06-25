import Darwin
import Foundation
import XCTest

@testable import MoaIMFCore

enum InjectedRenameFailure: Error {
  case expected
}

actor CandidateGate {
  private var arrived = false
  private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
  private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

  func arriveAndWait() async {
    arrived = true
    for waiter in arrivalWaiters { waiter.resume() }
    arrivalWaiters.removeAll()
    await withCheckedContinuation { releaseWaiters.append($0) }
  }

  func waitUntilArrived() async {
    guard !arrived else { return }
    await withCheckedContinuation { arrivalWaiters.append($0) }
  }

  func release() {
    for waiter in releaseWaiters { waiter.resume() }
    releaseWaiters.removeAll()
  }
}

final class RenameFixture {
  let root: URL
  let journal: RecoveryJournal

  init(fileManager: FileManager = .default) throws {
    root = fileManager.temporaryDirectory.appendingPathComponent(
      UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    journal = RecoveryJournal(directory: root.appendingPathComponent("journal", isDirectory: true))
  }

  @discardableResult
  func write(name: String, contents: String) throws -> URL {
    let url = root.appendingPathComponent(name)
    try Data(contents.utf8).write(to: url)
    return url
  }

  func candidate(rawName: String) throws -> RenameCandidate {
    let snapshot = try FileTreeScanner(excludedRoots: [root.appendingPathComponent("journal")])
      .scan(root: root)
    let entry = try XCTUnwrap(snapshot.entries.first { rawEqual($0.rawName, rawName) })
    return RenameCandidate(
      identity: entry.identity,
      source: entry.url,
      targetName: UnicodeNormalizer.nfc(rawName)
    )
  }

  func rawNames() throws -> [String] {
    try rawDirectoryNames(in: root)
      .filter { $0 != "journal" }
      .sorted { scalarPrecedes($0, $1) }
  }

  func remove(fileManager: FileManager = .default) {
    try? fileManager.removeItem(at: root)
  }

  private func rawEqual(_ left: String, _ right: String) -> Bool {
    left.utf8.elementsEqual(right.utf8)
  }

  private func scalarPrecedes(_ left: String, _ right: String) -> Bool {
    left.unicodeScalars.lexicographicallyPrecedes(right.unicodeScalars) { $0.value < $1.value }
  }
}

private func rawDirectoryNames(in directory: URL) throws -> [String] {
  try directory.withUnsafeFileSystemRepresentation { path in
    guard let path else { throw POSIXError(.EINVAL) }
    guard let stream = Darwin.opendir(path) else {
      throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
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

func setExtendedAttribute(name: String, value: String, at url: URL) throws {
  let bytes = Array(value.utf8)
  let result = try url.withUnsafeFileSystemRepresentation { path in
    guard let path else { throw POSIXError(.EINVAL) }
    return bytes.withUnsafeBytes { buffer in
      Darwin.setxattr(path, name, buffer.baseAddress, buffer.count, 0, 0)
    }
  }
  guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
}

func extendedAttribute(name: String, at url: URL) throws -> String {
  try url.withUnsafeFileSystemRepresentation { path in
    guard let path else { throw POSIXError(.EINVAL) }
    let size = Darwin.getxattr(path, name, nil, 0, 0, 0)
    guard size >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    var bytes = [UInt8](repeating: 0, count: size)
    let read = Darwin.getxattr(path, name, &bytes, bytes.count, 0, 0)
    guard read >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    return String(decoding: bytes.prefix(read), as: UTF8.self)
  }
}
