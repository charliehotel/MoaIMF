import Foundation

public struct FileFingerprint: Equatable, Sendable {
  public let identity: FileIdentity
  public let byteSize: Int64
  public let modifiedAt: Date

  public init(identity: FileIdentity, byteSize: Int64, modifiedAt: Date) {
    self.identity = identity
    self.byteSize = byteSize
    self.modifiedAt = modifiedAt
  }
}

public actor StabilityTracker {
  private struct Observation: Sendable {
    let fingerprint: FileFingerprint
    let unchangedSince: Date
  }

  private let quietPeriod: TimeInterval
  private var observations: [FileIdentity: Observation] = [:]

  public init(quietPeriod: TimeInterval = 30) {
    self.quietPeriod = quietPeriod
  }

  public func observe(_ entry: ScannedEntry, at date: Date = Date()) -> Bool {
    observeEntry(entry, at: date)
  }

  public func stableEntries(in snapshot: ScanSnapshot, at date: Date = Date()) -> [ScannedEntry] {
    let presentIdentities = Set(snapshot.entries.map(\.identity))
    observations = observations.filter { presentIdentities.contains($0.key) }

    var ownStability: [FileIdentity: Bool] = [:]
    for entry in snapshot.entries {
      ownStability[entry.identity] = observeEntry(entry, at: date)
    }
    let unstableEntries = snapshot.entries.filter { ownStability[$0.identity] != true }

    return snapshot.entries.filter { entry in
      guard ownStability[entry.identity] == true else { return false }
      guard entry.isDirectory else { return true }
      let prefix = entry.url.path.hasSuffix("/") ? entry.url.path : entry.url.path + "/"
      return !unstableEntries.contains { descendant in
        descendant.url.path.hasPrefix(prefix)
      }
    }
  }

  public func trackedIdentityCount() -> Int {
    observations.count
  }

  private func observeEntry(_ entry: ScannedEntry, at date: Date) -> Bool {
    guard entry.stabilityExclusion == nil else {
      observations.removeValue(forKey: entry.identity)
      return false
    }
    let fingerprint = FileFingerprint(
      identity: entry.identity,
      byteSize: entry.byteSize,
      modifiedAt: entry.modifiedAt
    )
    guard let existing = observations[entry.identity], existing.fingerprint == fingerprint else {
      observations[entry.identity] = Observation(fingerprint: fingerprint, unchangedSince: date)
      return false
    }
    return date.timeIntervalSince(existing.unchangedSince) >= quietPeriod
  }
}
