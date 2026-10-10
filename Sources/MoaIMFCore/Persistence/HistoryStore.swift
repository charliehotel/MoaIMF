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
  public let totalEventCount: Int

  public init(events: [HistoryEvent], diagnostics: [HistoryDiagnostic], totalEventCount: Int? = nil)
  {
    self.events = events
    self.diagnostics = diagnostics
    self.totalEventCount = totalEventCount ?? events.count
  }
}

public actor HistoryStore {
  private let fileURL: URL
  private let retentionInterval: TimeInterval
  private let now: @Sendable () -> Date
  private var lastPruneDate: Date?

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

  public func recordBatch(_ events: [HistoryEvent]) throws {
    guard !events.isEmpty else { return }
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
      var batchData = Data()
      for event in events {
        var data = try encoder().encode(event)
        data.append(0x0A)
        batchData.append(data)
      }
      try handle.write(contentsOf: batchData)
      try handle.synchronize()
      try handle.close()
    } catch {
      let writeError = error
      try? handle.close()
      throw writeError
    }
    try pruneIfNeeded(referenceDate: now())
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
    try pruneIfNeeded(referenceDate: now())
  }

  public func pruneIfNeeded(referenceDate: Date, force: Bool = false) throws {
    if !force, let lastPrune = lastPruneDate, referenceDate.timeIntervalSince(lastPrune) < 3600 {
      return
    }
    try prune(referenceDate: referenceDate)
    lastPruneDate = referenceDate
  }

  public func load(limit: Int? = nil) throws -> HistoryLoadResult {
    var events: [HistoryEvent] = []
    var diagnostics: [HistoryDiagnostic] = []
    guard FileManager.default.fileExists(atPath: fileURL.path) else {
      return HistoryLoadResult(events: [], diagnostics: [])
    }
    let handle = try FileHandle(forReadingFrom: fileURL)
    defer { try? handle.close() }
    var lineNumber = 0
    var totalEventCount = 0
    var pending = Data()
    while let chunk = try handle.read(upToCount: 64 * 1024), !chunk.isEmpty {
      pending.append(chunk)
      while let newline = pending.firstRange(of: Data([0x0A])) {
        lineNumber += 1
        let line = Data(pending[..<newline.lowerBound])
        pending.removeSubrange(..<newline.upperBound)
        try decodeHistoryLine(
          line,
          lineNumber: lineNumber,
          limit: limit,
          events: &events,
          diagnostics: &diagnostics,
          totalEventCount: &totalEventCount
        )
      }
    }
    if !pending.isEmpty {
      lineNumber += 1
      try decodeHistoryLine(
        pending,
        lineNumber: lineNumber,
        limit: limit,
        events: &events,
        diagnostics: &diagnostics,
        totalEventCount: &totalEventCount
      )
    }
    return HistoryLoadResult(
      events: events,
      diagnostics: diagnostics,
      totalEventCount: totalEventCount
    )
  }

  private func decodeHistoryLine(
    _ line: Data,
    lineNumber: Int,
    limit: Int?,
    events: inout [HistoryEvent],
    diagnostics: inout [HistoryDiagnostic],
    totalEventCount: inout Int
  ) throws {
    do {
      let event = try decoder().decode(HistoryEvent.self, from: line)
      guard event.schemaVersion == 1 else {
        diagnostics.append(
          HistoryDiagnostic(lineNumber: lineNumber, reason: "Unsupported history schema")
        )
        return
      }
      totalEventCount += 1
      events.append(event)
      if let limit, limit > 0, events.count > limit { events.removeFirst() }
    } catch {
      if let limit, limit > 0 {
        guard diagnostics.count < limit else { return }
      }
      diagnostics.append(
        HistoryDiagnostic(lineNumber: lineNumber, reason: String(describing: error))
      )
    }
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
