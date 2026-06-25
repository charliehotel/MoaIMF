import Darwin
import Foundation

public actor WatchedFolderStore {
  private struct Payload: Codable, Sendable {
    let version: Int
    let folders: [WatchedFolder]
  }

  private let fileURL: URL
  private let bookmarkCoder: any BookmarkCoding
  private let resourceAccessor: any ScopedResourceAccessing
  private var activeResources: [UUID: URL] = [:]

  public init(
    fileURL: URL,
    bookmarkCoder: any BookmarkCoding = FoundationBookmarkCoder(),
    resourceAccessor: any ScopedResourceAccessing = FoundationScopedResourceAccessor()
  ) {
    self.fileURL = fileURL
    self.bookmarkCoder = bookmarkCoder
    self.resourceAccessor = resourceAccessor
  }

  public func folders() throws -> [WatchedFolder] {
    let stored = try load()
    var refreshed: [WatchedFolder] = []
    for folder in stored {
      refreshed.append(refresh(folder))
    }
    if refreshed != stored { try persist(refreshed) }
    return refreshed
  }

  @discardableResult
  public func add(
    url: URL,
    mode: WatchedFolderNormalizationMode = .allItems
  ) throws -> WatchedFolder {
    let canonicalURL = canonical(url)
    guard resourceAccessor.start(canonicalURL) else {
      throw WatchedFolderError.accessDenied
    }
    defer { resourceAccessor.stop(canonicalURL) }
    let identity = try stableIdentity(for: canonicalURL)
    let existing = try folders()
    try ensureNoOverlap(url: canonicalURL, identity: identity, existing: existing)
    let excludedExistingIdentities = try existingIdentities(
      at: canonicalURL,
      mode: mode
    )
    let folder = WatchedFolder(
      id: UUID(),
      bookmarkData: try bookmarkCoder.create(for: canonicalURL),
      displayName: canonicalURL.lastPathComponent,
      isEnabled: true,
      lastStableIdentity: identity,
      status: .available,
      normalizationMode: mode,
      excludedExistingIdentities: excludedExistingIdentities
    )
    try persist(existing + [folder])
    return folder
  }

  public func remove(id: UUID) throws {
    var stored = try load()
    guard stored.contains(where: { $0.id == id }) else {
      throw WatchedFolderError.folderNotFound
    }
    stored.removeAll { $0.id == id }
    try persist(stored)
    stopActiveAccess(id: id)
  }

  public func setEnabled(id: UUID, enabled: Bool) throws {
    var stored = try load()
    guard let index = stored.firstIndex(where: { $0.id == id }) else {
      throw WatchedFolderError.folderNotFound
    }
    stored[index] = stored[index].updating(isEnabled: enabled)
    try persist(stored)
    if !enabled { stopActiveAccess(id: id) }
  }

  @discardableResult
  public func reselect(id: UUID, url: URL) throws -> WatchedFolder {
    let canonicalURL = canonical(url)
    guard resourceAccessor.start(canonicalURL) else {
      throw WatchedFolderError.accessDenied
    }
    defer { resourceAccessor.stop(canonicalURL) }
    let identity = try stableIdentity(for: canonicalURL)
    var stored = try load()
    guard let index = stored.firstIndex(where: { $0.id == id }) else {
      throw WatchedFolderError.folderNotFound
    }
    try ensureNoOverlap(
      url: canonicalURL,
      identity: identity,
      existing: stored.filter { $0.id != id }
    )
    let excludedExistingIdentities = try existingIdentities(
      at: canonicalURL,
      mode: stored[index].normalizationMode
    )
    let updated = stored[index].updating(
      bookmarkData: try bookmarkCoder.create(for: canonicalURL),
      displayName: canonicalURL.lastPathComponent,
      lastStableIdentity: .some(identity),
      status: .available,
      excludedExistingIdentities: excludedExistingIdentities
    )
    stored[index] = updated
    try persist(stored)
    stopActiveAccess(id: id)
    return updated
  }

  public func resolvedURL(id: UUID) throws -> URL {
    guard let folder = try load().first(where: { $0.id == id }) else {
      throw WatchedFolderError.folderNotFound
    }
    return try bookmarkCoder.resolve(folder.bookmarkData).url
  }

  public func activateEnabledFolders() throws -> [UUID: URL] {
    let enabled = try load().filter { $0.isEnabled && $0.status == .available }
    let enabledIDs = Set(enabled.map(\.id))
    let inactiveIDs = activeResources.keys.filter { !enabledIDs.contains($0) }
    for id in inactiveIDs { stopActiveAccess(id: id) }
    for folder in enabled where activeResources[folder.id] == nil {
      let url = try bookmarkCoder.resolve(folder.bookmarkData).url
      guard resourceAccessor.start(url) else { continue }
      activeResources[folder.id] = url
    }
    return activeResources
  }

  public func deactivateAllFolders() {
    for url in activeResources.values { resourceAccessor.stop(url) }
    activeResources = [:]
  }

  public func withAccess<T: Sendable>(
    id: UUID,
    operation: @Sendable (URL) async throws -> T
  ) async throws -> T {
    let stored = try load()
    guard let folder = stored.first(where: { $0.id == id }) else {
      throw WatchedFolderError.folderNotFound
    }
    let resolved = try bookmarkCoder.resolve(folder.bookmarkData)
    guard resourceAccessor.start(resolved.url) else {
      throw WatchedFolderError.accessDenied
    }
    defer { resourceAccessor.stop(resolved.url) }
    return try await operation(resolved.url)
  }

  private func refresh(_ folder: WatchedFolder) -> WatchedFolder {
    let resolved: ResolvedBookmark
    do {
      resolved = try bookmarkCoder.resolve(folder.bookmarkData)
    } catch {
      return folder.updating(status: .disconnected)
    }
    guard resourceAccessor.start(resolved.url) else {
      return folder.updating(status: .permissionRequired)
    }
    defer { resourceAccessor.stop(resolved.url) }
    do {
      let identity = try stableIdentity(for: canonical(resolved.url))
      let bookmarkData =
        resolved.isStale ? try bookmarkCoder.create(for: resolved.url) : folder.bookmarkData
      return folder.updating(
        bookmarkData: bookmarkData,
        lastStableIdentity: .some(identity),
        status: .available
      )
    } catch {
      return folder.updating(status: .disconnected)
    }
  }

  private func ensureNoOverlap(
    url: URL,
    identity: FileIdentity,
    existing: [WatchedFolder]
  ) throws {
    for folder in existing {
      guard let resolved = try? bookmarkCoder.resolve(folder.bookmarkData) else { continue }
      let existingURL = canonical(resolved.url)
      if folder.lastStableIdentity == identity || existingURL.path == url.path {
        throw WatchedFolderError.duplicateRoot
      }
      if isAncestor(existingURL, of: url) || isAncestor(url, of: existingURL) {
        throw WatchedFolderError.overlappingRoot
      }
    }
  }

  private func isAncestor(_ parent: URL, of child: URL) -> Bool {
    child.path.hasPrefix(parent.path.hasSuffix("/") ? parent.path : parent.path + "/")
  }

  private func load() throws -> [WatchedFolder] {
    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      return []
    }
    let payload = try JSONDecoder().decode(Payload.self, from: data)
    guard payload.version == 1 else { throw WatchedFolderError.unsupportedVersion }
    return payload.folders
  }

  private func persist(_ folders: [WatchedFolder]) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(Payload(version: 1, folders: folders)).write(to: fileURL, options: .atomic)
  }

  private func canonical(_ url: URL) -> URL {
    let resolvedPath = url.withUnsafeFileSystemRepresentation { path -> String? in
      guard let path, let resolved = Darwin.realpath(path, nil) else { return nil }
      defer { free(resolved) }
      return String(cString: resolved)
    }
    return resolvedPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
      ?? url.standardizedFileURL
  }

  private func stableIdentity(for url: URL) throws -> FileIdentity {
    let values = try url.resourceValues(forKeys: [.volumeIdentifierKey, .fileResourceIdentifierKey])
    guard let volume = values.volumeIdentifier, let resource = values.fileResourceIdentifier else {
      throw WatchedFolderError.invalidBookmark
    }
    return FileIdentity(volume: describe(volume), resource: describe(resource))
  }

  private func existingIdentities(
    at url: URL,
    mode: WatchedFolderNormalizationMode
  ) throws -> Set<FileIdentity> {
    guard mode == .newItemsOnly else { return [] }
    return Set(try FileTreeScanner().scan(root: url).entries.map(\.identity))
  }

  private func describe(_ value: Any) -> String {
    if let data = value as? Data { return data.base64EncodedString() }
    if let number = value as? NSNumber { return number.stringValue }
    if let string = value as? String { return string }
    return String(reflecting: value)
  }

  private func stopActiveAccess(id: UUID) {
    guard let url = activeResources.removeValue(forKey: id) else { return }
    resourceAccessor.stop(url)
  }
}
