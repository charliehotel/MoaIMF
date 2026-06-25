import Foundation

public enum RenameRecoveryPhase: String, Codable, Sendable {
  case planned
  case temporary
  case completed
  case rolledBack
}

public struct RenameRecoveryRecord: Equatable, Codable, Sendable {
  public let operationID: UUID
  public let identity: FileIdentity
  public let originalURL: URL
  public let temporaryURL: URL
  public let targetURL: URL
  public let targetName: String
  public let phase: RenameRecoveryPhase

  public init(
    operationID: UUID,
    identity: FileIdentity,
    originalURL: URL,
    temporaryURL: URL,
    targetURL: URL,
    targetName: String,
    phase: RenameRecoveryPhase
  ) {
    self.operationID = operationID
    self.identity = identity
    self.originalURL = originalURL
    self.temporaryURL = temporaryURL
    self.targetURL = targetURL
    self.targetName = targetName
    self.phase = phase
  }

  public func updating(phase: RenameRecoveryPhase) -> RenameRecoveryRecord {
    RenameRecoveryRecord(
      operationID: operationID,
      identity: identity,
      originalURL: originalURL,
      temporaryURL: temporaryURL,
      targetURL: targetURL,
      targetName: targetName,
      phase: phase
    )
  }
}

public actor RecoveryJournal {
  private let directory: URL
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  public init(directory: URL) {
    self.directory = directory
    encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    decoder = JSONDecoder()
  }

  public func write(_ record: RenameRecoveryRecord) throws {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try encoder.encode(record).write(to: fileURL(for: record.operationID), options: .atomic)
  }

  public func activeRecords() throws -> [RenameRecoveryRecord] {
    let files: [URL]
    do {
      files = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      return []
    }
    return try files.filter { $0.pathExtension == "json" }
      .map { try decoder.decode(RenameRecoveryRecord.self, from: Data(contentsOf: $0)) }
      .sorted { $0.operationID.uuidString < $1.operationID.uuidString }
  }

  public func remove(operationID: UUID) throws {
    try FileManager.default.removeItem(at: fileURL(for: operationID))
  }

  private func fileURL(for operationID: UUID) -> URL {
    directory.appendingPathComponent(operationID.uuidString).appendingPathExtension("json")
  }
}
