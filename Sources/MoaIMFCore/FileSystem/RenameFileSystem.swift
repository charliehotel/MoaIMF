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

struct RenameFileSystem: Sendable {
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
  }

  func moveExclusively(from source: URL, toParent parent: URL, rawName: String) throws {
    try moveExclusively(
      from: pathBytes(for: source), to: siblingPathBytes(parent: parent, rawName: rawName))
  }

  func moveExclusively(fromParent parent: URL, rawName: String, to target: URL) throws {
    try moveExclusively(
      from: siblingPathBytes(parent: parent, rawName: rawName), to: pathBytes(for: target))
  }

  func rawNames(in directory: URL) throws -> [String] {
    try RawDirectoryReader().names(in: directory)
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
