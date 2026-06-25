import Foundation

public enum HistoryEventKind: String, Codable, Sendable {
  case renamed
  case collision
  case permission
  case disconnected
  case unsupportedFilesystem
  case error
}

public struct HistoryEvent: Identifiable, Codable, Equatable, Sendable {
  public let schemaVersion: Int
  public let id: UUID
  public let timestamp: Date
  public let kind: HistoryEventKind
  public let rootIdentifier: String
  public let previousURL: URL?
  public let resultingURL: URL?
  public let reason: String

  public init(
    schemaVersion: Int = 1,
    id: UUID = UUID(),
    timestamp: Date,
    kind: HistoryEventKind,
    rootIdentifier: String,
    previousURL: URL?,
    resultingURL: URL?,
    reason: String
  ) {
    self.schemaVersion = schemaVersion
    self.id = id
    self.timestamp = timestamp
    self.kind = kind
    self.rootIdentifier = rootIdentifier
    self.previousURL = previousURL
    self.resultingURL = resultingURL
    self.reason = reason
  }
}

public struct HistoryDiagnostic: Equatable, Sendable {
  public let lineNumber: Int
  public let reason: String

  public init(lineNumber: Int, reason: String) {
    self.lineNumber = lineNumber
    self.reason = reason
  }
}

public struct HistoryLoadResult: Equatable, Sendable {
  public let events: [HistoryEvent]
  public let diagnostics: [HistoryDiagnostic]

  public init(events: [HistoryEvent], diagnostics: [HistoryDiagnostic]) {
    self.events = events
    self.diagnostics = diagnostics
  }
}

public actor HistoryStore {
  private let fileURL: URL
  private let retentionInterval: TimeInterval
  private let now: @Sendable () -> Date

  public init(
    fileURL: URL,
    retentionInterval: TimeInterval = 30 * 24 * 60 * 60,
    now: @escaping @Sendable () -> Date = Date.init
  ) {
    self.fileURL = fileURL
    self.retentionInterval = retentionInterval
    self.now = now
  }

  @discardableResult
  public func record(
    kind: HistoryEventKind,
    rootIdentifier: String,
    previousURL: URL?,
    resultingURL: URL?,
    reason: String
  ) throws -> HistoryEvent {
    let event = HistoryEvent(
      timestamp: now(),
      kind: kind,
      rootIdentifier: rootIdentifier,
      previousURL: previousURL,
      resultingURL: resultingURL,
      reason: reason
    )
    try append(event)
    return event
  }

  public func append(_ event: HistoryEvent) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    if !FileManager.default.fileExists(atPath: fileURL.path) {
      try Data().write(to: fileURL, options: .atomic)
    }
    let handle = try FileHandle(forWritingTo: fileURL)
    do {
      try handle.seekToEnd()
      var data = try encoder().encode(event)
      data.append(0x0A)
      try handle.write(contentsOf: data)
      try handle.synchronize()
      try handle.close()
    } catch {
      let writeError = error
      do {
        try handle.close()
      } catch {
        throw error
      }
      throw writeError
    }
    try prune(referenceDate: now())
  }

  public func load() throws -> HistoryLoadResult {
    let lines = try readLines()
    var events: [HistoryEvent] = []
    var diagnostics: [HistoryDiagnostic] = []
    for (index, line) in lines.enumerated() {
      do {
        let event = try decoder().decode(HistoryEvent.self, from: line)
        guard event.schemaVersion == 1 else {
          diagnostics.append(
            HistoryDiagnostic(lineNumber: index + 1, reason: "Unsupported history schema")
          )
          continue
        }
        events.append(event)
      } catch {
        diagnostics.append(
          HistoryDiagnostic(lineNumber: index + 1, reason: String(describing: error))
        )
      }
    }
    return HistoryLoadResult(events: events, diagnostics: diagnostics)
  }

  private func prune(referenceDate: Date) throws {
    let lines = try readLines()
    let cutoff = referenceDate.addingTimeInterval(-retentionInterval)
    var retained: [Data] = []
    for line in lines {
      do {
        let event = try decoder().decode(HistoryEvent.self, from: line)
        if event.schemaVersion != 1 || event.timestamp >= cutoff { retained.append(line) }
      } catch {
        retained.append(line)
      }
    }
    var data = Data()
    for line in retained {
      data.append(line)
      data.append(0x0A)
    }
    try data.write(to: fileURL, options: .atomic)
  }

  private func readLines() throws -> [Data] {
    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      return []
    }
    return Array(data).split(separator: 0x0A, omittingEmptySubsequences: true).map { Data($0) }
  }

  private func encoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [.sortedKeys]
    return encoder
  }

  private func decoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
  }
}
