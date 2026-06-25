import Darwin
import Foundation

public struct ScannedEntry: Equatable, Sendable {
  public let identity: FileIdentity
  public let url: URL
  public let rawName: String
  public let depth: Int
  public let isDirectory: Bool
  public let isSymbolicLink: Bool
  public let isPackage: Bool
  public let byteSize: Int64
  public let modifiedAt: Date
  public let stabilityExclusion: StabilityExclusionMatch?

  public init(
    identity: FileIdentity,
    url: URL,
    rawName: String,
    depth: Int,
    isDirectory: Bool,
    isSymbolicLink: Bool,
    isPackage: Bool,
    byteSize: Int64,
    modifiedAt: Date,
    stabilityExclusion: StabilityExclusionMatch? = nil
  ) {
    self.identity = identity
    self.url = url
    self.rawName = rawName
    self.depth = depth
    self.isDirectory = isDirectory
    self.isSymbolicLink = isSymbolicLink
    self.isPackage = isPackage
    self.byteSize = byteSize
    self.modifiedAt = modifiedAt
    self.stabilityExclusion = stabilityExclusion
  }
}

public struct ScanSnapshot: Equatable, Sendable {
  public let root: URL
  public let caseSensitive: Bool
  public let entries: [ScannedEntry]

  public init(root: URL, caseSensitive: Bool, entries: [ScannedEntry]) {
    self.root = root
    self.caseSensitive = caseSensitive
    self.entries = entries
  }
}

public enum ScanError: Error, Equatable, Sendable {
  case cannotEnumerate(URL)
  case enumerationFailed(URL, String)
  case missingStableIdentity(URL)
}

public struct FileTreeScanner: Sendable {
  private static let resourceKeys: Set<URLResourceKey> = [
    .contentModificationDateKey,
    .fileResourceIdentifierKey,
    .fileSizeKey,
    .isDirectoryKey,
    .isPackageKey,
    .isSymbolicLinkKey,
    .nameKey,
    .volumeIdentifierKey,
  ]

  private let excludedRoots: [URL]

  public init(excludedRoots: [URL] = []) {
    self.excludedRoots = excludedRoots.map(Self.canonicalURL)
  }

  public func scan(
    root: URL,
    matcher: StabilityExclusionMatcher? = nil
  ) throws -> ScanSnapshot {
    let standardizedRoot = Self.canonicalURL(root)
    let rootValues = try standardizedRoot.resourceValues(
      forKeys: [.volumeSupportsCaseSensitiveNamesKey]
    )
    var enumerationFailure: ScanError?
    guard
      let enumerator = FileManager.default.enumerator(
        at: standardizedRoot,
        includingPropertiesForKeys: Array(Self.resourceKeys),
        options: [.skipsPackageDescendants],
        errorHandler: { url, error in
          enumerationFailure = .enumerationFailed(url, error.localizedDescription)
          return false
        }
      )
    else {
      throw ScanError.cannotEnumerate(standardizedRoot)
    }

    var entries: [ScannedEntry] = []
    for case let url as URL in enumerator {
      if isExcluded(url) {
        enumerator.skipDescendants()
        continue
      }

      let values = try url.resourceValues(forKeys: Self.resourceKeys)
      let isSymbolicLink = values.isSymbolicLink == true
      let isDirectory = values.isDirectory == true
      let rawName = values.name ?? url.lastPathComponent
      let exclusion = matcher?.match(
        name: rawName,
        caseSensitive: rootValues.volumeSupportsCaseSensitiveNames ?? true
      )
      if isSymbolicLink || (isDirectory && exclusion != nil) {
        enumerator.skipDescendants()
      }

      entries.append(
        ScannedEntry(
          identity: try identity(for: url, values: values),
          url: url,
          rawName: rawName,
          depth: max(0, url.pathComponents.count - standardizedRoot.pathComponents.count),
          isDirectory: isDirectory,
          isSymbolicLink: isSymbolicLink,
          isPackage: values.isPackage == true,
          byteSize: Int64(values.fileSize ?? 0),
          modifiedAt: values.contentModificationDate ?? .distantPast,
          stabilityExclusion: exclusion
        )
      )
    }

    if let enumerationFailure {
      throw enumerationFailure
    }
    return ScanSnapshot(
      root: standardizedRoot,
      caseSensitive: rootValues.volumeSupportsCaseSensitiveNames ?? true,
      entries: entries
    )
  }

  private func isExcluded(_ url: URL) -> Bool {
    let candidatePath = url.path
    return excludedRoots.contains { excludedRoot in
      let excludedPath = excludedRoot.path
      return candidatePath == excludedPath || candidatePath.hasPrefix(excludedPath + "/")
    }
  }

  private func identity(for url: URL, values: URLResourceValues) throws -> FileIdentity {
    if let volume = values.volumeIdentifier, let resource = values.fileResourceIdentifier {
      return FileIdentity(
        volume: stableDescription(volume),
        resource: stableDescription(resource)
      )
    }

    var metadata = stat()
    let result = url.withUnsafeFileSystemRepresentation { path in
      guard let path else { return Int32(-1) }
      return Darwin.lstat(path, &metadata)
    }
    guard result == 0 else {
      throw ScanError.missingStableIdentity(url)
    }
    return FileIdentity(
      volume: String(metadata.st_dev),
      resource: String(metadata.st_ino)
    )
  }

  private func stableDescription(_ value: Any) -> String {
    if let data = value as? Data {
      return data.base64EncodedString()
    }
    if let number = value as? NSNumber {
      return number.stringValue
    }
    if let string = value as? String {
      return string
    }
    return String(reflecting: value)
  }

  private static func canonicalURL(_ url: URL) -> URL {
    let resolvedPath = url.withUnsafeFileSystemRepresentation { path -> String? in
      guard let path, let resolved = Darwin.realpath(path, nil) else { return nil }
      defer { free(resolved) }
      return String(cString: resolved)
    }
    guard let resolvedPath else { return url.standardizedFileURL }
    return URL(fileURLWithPath: resolvedPath, isDirectory: url.hasDirectoryPath)
  }
}
