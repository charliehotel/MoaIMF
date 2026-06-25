import Foundation

public enum WatchedFolderStatus: String, Codable, Sendable {
  case available
  case permissionRequired
  case disconnected
}

public enum WatchedFolderNormalizationMode: String, Codable, Sendable {
  case allItems
  case newItemsOnly
}

public struct WatchedFolder: Identifiable, Codable, Equatable, Sendable {
  public let id: UUID
  public let bookmarkData: Data
  public let displayName: String
  public let isEnabled: Bool
  public let lastStableIdentity: FileIdentity?
  public let status: WatchedFolderStatus
  public let normalizationMode: WatchedFolderNormalizationMode
  public let excludedExistingIdentities: Set<FileIdentity>

  public init(
    id: UUID,
    bookmarkData: Data,
    displayName: String,
    isEnabled: Bool,
    lastStableIdentity: FileIdentity?,
    status: WatchedFolderStatus,
    normalizationMode: WatchedFolderNormalizationMode = .allItems,
    excludedExistingIdentities: Set<FileIdentity> = []
  ) {
    self.id = id
    self.bookmarkData = bookmarkData
    self.displayName = displayName
    self.isEnabled = isEnabled
    self.lastStableIdentity = lastStableIdentity
    self.status = status
    self.normalizationMode = normalizationMode
    self.excludedExistingIdentities = excludedExistingIdentities
  }

  func updating(
    bookmarkData: Data? = nil,
    displayName: String? = nil,
    isEnabled: Bool? = nil,
    lastStableIdentity: FileIdentity?? = nil,
    status: WatchedFolderStatus? = nil,
    normalizationMode: WatchedFolderNormalizationMode? = nil,
    excludedExistingIdentities: Set<FileIdentity>? = nil
  ) -> WatchedFolder {
    WatchedFolder(
      id: id,
      bookmarkData: bookmarkData ?? self.bookmarkData,
      displayName: displayName ?? self.displayName,
      isEnabled: isEnabled ?? self.isEnabled,
      lastStableIdentity: lastStableIdentity ?? self.lastStableIdentity,
      status: status ?? self.status,
      normalizationMode: normalizationMode ?? self.normalizationMode,
      excludedExistingIdentities: excludedExistingIdentities ?? self.excludedExistingIdentities
    )
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case bookmarkData
    case displayName
    case isEnabled
    case lastStableIdentity
    case status
    case normalizationMode
    case excludedExistingIdentities
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    bookmarkData = try container.decode(Data.self, forKey: .bookmarkData)
    displayName = try container.decode(String.self, forKey: .displayName)
    isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    lastStableIdentity = try container.decodeIfPresent(
      FileIdentity.self,
      forKey: .lastStableIdentity
    )
    status = try container.decode(WatchedFolderStatus.self, forKey: .status)
    normalizationMode =
      try container.decodeIfPresent(WatchedFolderNormalizationMode.self, forKey: .normalizationMode)
      ?? .allItems
    excludedExistingIdentities =
      try container.decodeIfPresent(Set<FileIdentity>.self, forKey: .excludedExistingIdentities)
      ?? []
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(id, forKey: .id)
    try container.encode(bookmarkData, forKey: .bookmarkData)
    try container.encode(displayName, forKey: .displayName)
    try container.encode(isEnabled, forKey: .isEnabled)
    try container.encodeIfPresent(lastStableIdentity, forKey: .lastStableIdentity)
    try container.encode(status, forKey: .status)
    try container.encode(normalizationMode, forKey: .normalizationMode)
    try container.encode(excludedExistingIdentities, forKey: .excludedExistingIdentities)
  }
}

public enum WatchedFolderError: Error, Equatable, Sendable {
  case duplicateRoot
  case overlappingRoot
  case folderNotFound
  case accessDenied
  case invalidBookmark
  case unsupportedVersion
}
