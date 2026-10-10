import Darwin
import Foundation

enum RenameFileSystemError: Error, LocalizedError {
  case sourceMissing(URL)
  case identityChanged(URL)
  case collision(URL)
  case verificationFailed(URL)

  var errorDescription: String? {
    switch self {
    case .sourceMissing(let url): "Source entry is missing: \(url.path)"
    case .identityChanged(let url): "Source identity changed: \(url.path)"
    case .collision(let url): "Target name collides with a sibling: \(url.lastPathComponent)"
    case .verificationFailed(let url): "Stored NFC name could not be verified: \(url.path)"
    }
  }
}

final class DirectoryEntryCache: @unchecked Sendable {
  private let lock = NSLock()
  private var cache: [URL: Set<String>] = [:]

  func names(in directory: URL) throws -> Set<String> {
    lock.lock()
    if let cached = cache[directory] {
      lock.unlock()
      return cached
    }
    lock.unlock()

    let freshList = try RawDirectoryReader().names(in: directory)
    let freshSet = Set(freshList)
    lock.lock()
    cache[directory] = freshSet
    lock.unlock()
    return freshSet
  }

  func contains(_ name: String, in directory: URL) throws -> Bool {
    try names(in: directory).contains(where: { $0.utf8.elementsEqual(name.utf8) })
  }

  func findRawName(matching name: String, in directory: URL) throws -> String? {
    try names(in: directory).first(where: { $0.utf8.elementsEqual(name.utf8) })
  }

  func didRename(from oldName: String, to newName: String, in directory: URL) {
    lock.lock()
    defer { lock.unlock() }
    guard var names = cache[directory] else { return }
    names = names.filter { !$0.utf8.elementsEqual(oldName.utf8) }
    names.insert(newName)
    cache[directory] = names
  }

  func didRemove(_ name: String, in directory: URL) {
    lock.lock()
    defer { lock.unlock() }
    guard var names = cache[directory] else { return }
    names = names.filter { !$0.utf8.elementsEqual(name.utf8) }
    cache[directory] = names
  }

  func didInsert(_ name: String, in directory: URL) {
    lock.lock()
    defer { lock.unlock() }
    guard var names = cache[directory] else { return }
    names.insert(name)
    cache[directory] = names
  }

  func invalidate(directory: URL) {
    lock.lock()
    defer { lock.unlock() }
    cache.removeValue(forKey: directory)
  }

  func clear() {
    lock.lock()
    defer { lock.unlock() }
    cache.removeAll()
  }
}

struct RenameFileSystem: Sendable {
  private let cache: DirectoryEntryCache?

  init(cache: DirectoryEntryCache? = nil) {
    self.cache = cache
  }

  func preflight(_ candidate: RenameCandidate) throws -> URL {
    let parent = candidate.source.deletingLastPathComponent()
    let sourceName = candidate.source.lastPathComponent
    let names = try rawNames(in: parent)
    guard names.contains(where: { rawEqual($0, sourceName) }) else {
      throw RenameFileSystemError.sourceMissing(candidate.source)
    }
    guard try hasIdentity(candidate.identity, at: candidate.source) else {
      throw RenameFileSystemError.identityChanged(candidate.source)
    }

    let caseSensitive =
      try parent.resourceValues(
        forKeys: [.volumeSupportsCaseSensitiveNamesKey]
      ).volumeSupportsCaseSensitiveNames ?? true
    let targetKey = comparisonKey(candidate.targetName, caseSensitive: caseSensitive)
    let matchingNames = names.filter {
      comparisonKey($0, caseSensitive: caseSensitive) == targetKey
    }
    guard matchingNames.count == 1 else {
      throw RenameFileSystemError.collision(parent.appendingPathComponent(candidate.targetName))
    }
    return parent.appendingPathComponent(candidate.targetName)
  }

  func isVerifiedTarget(_ target: URL, rawTargetName: String, identity: FileIdentity) throws -> Bool
  {
    let parent = target.deletingLastPathComponent()
    guard
      let rawName = try rawNames(in: parent).first(where: { rawEqual($0, rawTargetName) }),
      UnicodeNormalizer.isNFC(rawName)
    else {
      return false
    }
    return try hasIdentity(identity, in: parent, rawName: rawName)
  }

  func hasIdentity(_ expected: FileIdentity, at url: URL) throws -> Bool {
    let parent = url.deletingLastPathComponent()
    let expectedName = url.lastPathComponent
    guard let rawName = try rawNames(in: parent).first(where: { rawEqual($0, expectedName) }) else {
      return false
    }
    return try identity(for: parent.appendingPathComponent(rawName)) == expected
  }

  func hasIdentity(_ expected: FileIdentity, in parent: URL, rawName: String) throws -> Bool {
    guard try rawNames(in: parent).contains(where: { rawEqual($0, rawName) }) else {
      return false
    }
    return try identity(for: parent.appendingPathComponent(rawName)) == expected
  }

  func moveExclusively(from source: URL, to target: URL) throws {
    try moveExclusively(from: pathBytes(for: source), to: pathBytes(for: target))
    if let cache {
      let sourceParent = source.deletingLastPathComponent()
      let targetParent = target.deletingLastPathComponent()
      if sourceParent == targetParent {
        cache.didRename(from: source.lastPathComponent, to: target.lastPathComponent, in: sourceParent)
      } else {
        cache.didRemove(source.lastPathComponent, in: sourceParent)
        cache.didInsert(target.lastPathComponent, in: targetParent)
      }
    }
  }

  func moveExclusively(from source: URL, toParent parent: URL, rawName: String) throws {
    try moveExclusively(
      from: pathBytes(for: source), to: siblingPathBytes(parent: parent, rawName: rawName))
    if let cache {
      let sourceParent = source.deletingLastPathComponent()
      if sourceParent == parent {
        cache.didRename(from: source.lastPathComponent, to: rawName, in: parent)
      } else {
        cache.didRemove(source.lastPathComponent, in: sourceParent)
        cache.didInsert(rawName, in: parent)
      }
    }
  }

  func moveExclusively(fromParent parent: URL, rawName: String, to target: URL) throws {
    try moveExclusively(
      from: siblingPathBytes(parent: parent, rawName: rawName), to: pathBytes(for: target))
    if let cache {
      let targetParent = target.deletingLastPathComponent()
      if parent == targetParent {
        cache.didRename(from: rawName, to: target.lastPathComponent, in: parent)
      } else {
        cache.didRemove(rawName, in: parent)
        cache.didInsert(target.lastPathComponent, in: targetParent)
      }
    }
  }

  func rawNames(in directory: URL) throws -> [String] {
    if let cache {
      return try Array(cache.names(in: directory))
    }
    return try RawDirectoryReader().names(in: directory)
  }

  func sameDirectory(_ left: URL, _ right: URL) -> Bool {
    do {
      return try identity(for: left) == identity(for: right)
    } catch {
      return left.path == right.path
    }
  }

  func rawEqual(_ left: String, _ right: String) -> Bool {
    left.utf8.elementsEqual(right.utf8)
  }

  private func comparisonKey(_ name: String, caseSensitive: Bool) -> String {
    let normalized = UnicodeNormalizer.nfc(name)
    return caseSensitive
      ? normalized
      : normalized.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
  }

  private func identity(for url: URL) throws -> FileIdentity {
    let values = try url.resourceValues(forKeys: [.volumeIdentifierKey, .fileResourceIdentifierKey])
    if let volume = values.volumeIdentifier, let resource = values.fileResourceIdentifier {
      return FileIdentity(volume: stableDescription(volume), resource: stableDescription(resource))
    }

    var metadata = stat()
    let result = url.withUnsafeFileSystemRepresentation { path in
      guard let path else { return Int32(-1) }
      return Darwin.lstat(path, &metadata)
    }
    guard result == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .ENOENT) }
    return FileIdentity(volume: String(metadata.st_dev), resource: String(metadata.st_ino))
  }

  private func stableDescription(_ value: Any) -> String {
    if let data = value as? Data { return data.base64EncodedString() }
    if let number = value as? NSNumber { return number.stringValue }
    if let string = value as? String { return string }
    return String(reflecting: value)
  }

  private func pathBytes(for url: URL) throws -> [UInt8] {
    try url.withUnsafeFileSystemRepresentation { path in
      guard let path else { throw POSIXError(.EINVAL) }
      return Array(UnsafeBufferPointer(start: path, count: strlen(path))).map {
        UInt8(bitPattern: $0)
      } + [0]
    }
  }

  private func siblingPathBytes(parent: URL, rawName: String) throws -> [UInt8] {
    var bytes = try pathBytes(for: parent)
    bytes.removeLast()
    if bytes.last != 47 { bytes.append(47) }
    bytes.append(contentsOf: rawName.utf8)
    bytes.append(0)
    return bytes
  }

  private func moveExclusively(from source: [UInt8], to target: [UInt8]) throws {
    try source.withUnsafeBytes { sourceBuffer in
      guard let sourcePath = sourceBuffer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
        throw POSIXError(.EINVAL)
      }
      try target.withUnsafeBytes { targetBuffer in
        guard let targetPath = targetBuffer.baseAddress?.assumingMemoryBound(to: CChar.self) else {
          throw POSIXError(.EINVAL)
        }
        guard
          renameatx_np(
            AT_FDCWD,
            sourcePath,
            AT_FDCWD,
            targetPath,
            UInt32(RENAME_EXCL)
          ) == 0
        else {
          throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
      }
    }
  }
}
