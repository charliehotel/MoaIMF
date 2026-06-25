import Foundation

public struct SiblingEntry: Equatable, Sendable {
  public let identity: FileIdentity
  public let parent: URL
  public let rawName: String
  public let isDirectory: Bool

  public init(identity: FileIdentity, parent: URL, rawName: String, isDirectory: Bool) {
    self.identity = identity
    self.parent = parent
    self.rawName = rawName
    self.isDirectory = isDirectory
  }
}

public struct RenameCandidate: Equatable, Sendable {
  public let identity: FileIdentity
  public let source: URL
  public let targetName: String

  public init(identity: FileIdentity, source: URL, targetName: String) {
    self.identity = identity
    self.source = source
    self.targetName = targetName
  }
}

public struct NormalizationCollision: Equatable, Sendable {
  public let parent: URL
  public let normalizedKey: String
  public let rawNames: [String]

  public init(parent: URL, normalizedKey: String, rawNames: [String]) {
    self.parent = parent
    self.normalizedKey = normalizedKey
    self.rawNames = rawNames
  }
}

public struct NormalizationPlan: Equatable, Sendable {
  public let candidates: [RenameCandidate]
  public let collisions: [NormalizationCollision]

  public init(candidates: [RenameCandidate], collisions: [NormalizationCollision]) {
    self.candidates = candidates
    self.collisions = collisions
  }
}

public enum RenameOutcomeKind: String, Codable, Sendable {
  case renamed
  case rolledBack
  case failed
}

public struct RenameOutcome: Equatable, Codable, Sendable {
  public let identity: FileIdentity
  public let source: URL
  public let target: URL
  public let kind: RenameOutcomeKind
  public let reason: String?

  public init(
    identity: FileIdentity,
    source: URL,
    target: URL,
    kind: RenameOutcomeKind,
    reason: String?
  ) {
    self.identity = identity
    self.source = source
    self.target = target
    self.kind = kind
    self.reason = reason
  }
}
