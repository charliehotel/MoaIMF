import Foundation
import MoaIMFCore

public enum AppStatus: Equatable, Sendable {
  case watching
  case scanning
  case paused
  case attention
  case noFolders
  case permissionRequired
  case disconnected
  case unsupported

  public var localizationKey: String {
    switch self {
    case .watching: "status.watching"
    case .scanning: "status.scanning"
    case .paused: "status.paused"
    case .attention: "status.attention"
    case .noFolders: "status.noFolders"
    case .permissionRequired: "status.permissionRequired"
    case .disconnected: "status.disconnected"
    case .unsupported: "status.unsupported"
    }
  }

  public var symbolName: String {
    switch self {
    case .watching: "checkmark.circle"
    case .scanning: "arrow.triangle.2.circlepath"
    case .paused: "pause.circle"
    case .attention, .permissionRequired, .unsupported: "exclamationmark.triangle"
    case .noFolders: "folder.badge.questionmark"
    case .disconnected: "externaldrive.badge.exclamationmark"
    }
  }
}

public struct AppFolder: Identifiable, Equatable, Sendable {
  public let id: UUID
  public let url: URL
  public let displayName: String
  public let isEnabled: Bool
  public let status: WatchedFolderStatus
  public let lastScan: Date?
  public let collisionCount: Int
  public let normalizationMode: WatchedFolderNormalizationMode
  public let excludedExistingIdentities: Set<FileIdentity>

  public init(
    id: UUID,
    url: URL,
    displayName: String,
    isEnabled: Bool,
    status: WatchedFolderStatus,
    lastScan: Date? = nil,
    collisionCount: Int = 0,
    normalizationMode: WatchedFolderNormalizationMode = .allItems,
    excludedExistingIdentities: Set<FileIdentity> = []
  ) {
    self.id = id
    self.url = url
    self.displayName = displayName
    self.isEnabled = isEnabled
    self.status = status
    self.lastScan = lastScan
    self.collisionCount = collisionCount
    self.normalizationMode = normalizationMode
    self.excludedExistingIdentities = excludedExistingIdentities
  }
}

public struct PreviewState: Equatable, Sendable {
  public let root: URL
  public let result: ScanServiceResult

  public var totalCount: Int { result.summary.totalEntryCount }
  public var nfcCount: Int { result.summary.nfcEntryCount }
  public var nonNFCCount: Int {
    if result.summary.totalEntryCount == 0 {
      return result.plan.candidates.count
    }
    return result.summary.nonNFCEntryCount
  }
  public var actionableNonNFCCount: Int { result.plan.candidates.count }
  public var collisionCount: Int { result.plan.collisions.count }
  public var deferredCount: Int { result.deferredIdentities.count }

  public init(root: URL, result: ScanServiceResult) {
    self.root = root
    self.result = result
  }
}

public struct FolderScanReport: Equatable, Sendable {
  public let root: URL
  public let scannedAt: Date
  public let result: ScanServiceResult

  public var totalCount: Int { result.summary.totalEntryCount }
  public var nfcCount: Int { result.summary.nfcEntryCount }
  public var nonNFCCount: Int {
    if result.summary.totalEntryCount == 0 {
      return result.plan.candidates.count
    }
    return result.summary.nonNFCEntryCount
  }
  public var actionableNonNFCCount: Int { result.plan.candidates.count }
  public var collisionCount: Int { result.plan.collisions.count }
  public var deferredCount: Int { result.deferredIdentities.count }
  public var renamedCount: Int { result.outcomes.filter { $0.kind == .renamed }.count }
  public var failedCount: Int { result.outcomes.filter { $0.kind == .failed }.count }
  public var candidateSamples: [RenameCandidate] { Array(result.plan.candidates.prefix(5)) }

  public init(root: URL, scannedAt: Date, result: ScanServiceResult) {
    self.root = root
    self.scannedAt = scannedAt
    self.result = result
  }
}

public struct AppAlert: Identifiable, Equatable, Sendable {
  public let id = UUID()
  public let localizationKey: String
  public let detail: String?

  public init(localizationKey: String, detail: String? = nil) {
    self.localizationKey = localizationKey
    self.detail = detail
  }

  public static func == (lhs: AppAlert, rhs: AppAlert) -> Bool {
    lhs.localizationKey == rhs.localizationKey && lhs.detail == rhs.detail
  }
}
