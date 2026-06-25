import Foundation

extension SafeRenameEngine {
  public func recoverPendingOperations() async throws -> [RenameOutcome] {
    var outcomes: [RenameOutcome] = []
    for record in try await journal.activeRecords() {
      if try fileSystem.isVerifiedTarget(
        record.targetURL,
        rawTargetName: record.targetName,
        identity: record.identity
      ) {
        try await finish(record.updating(phase: .completed))
        outcomes.append(
          RenameOutcome(
            identity: record.identity,
            source: record.originalURL,
            target: record.targetURL,
            kind: .renamed,
            reason: "Recovered completed rename"
          )
        )
      } else if try await restore(record) {
        try await finish(record.updating(phase: .rolledBack))
        outcomes.append(
          RenameOutcome(
            identity: record.identity,
            source: record.originalURL,
            target: record.targetURL,
            kind: .rolledBack,
            reason: "Recovered original name"
          )
        )
      } else {
        outcomes.append(
          RenameOutcome(
            identity: record.identity,
            source: record.originalURL,
            target: record.targetURL,
            kind: .failed,
            reason: "Recovery could not locate the original identity"
          )
        )
      }
    }
    return outcomes
  }

  func restore(_ record: RenameRecoveryRecord) async throws -> Bool {
    if try fileSystem.hasIdentity(record.identity, at: record.originalURL) { return true }
    if try fileSystem.hasIdentity(record.identity, at: record.temporaryURL) {
      try fileSystem.moveExclusively(from: record.temporaryURL, to: record.originalURL)
    } else if try fileSystem.isVerifiedTarget(
      record.targetURL,
      rawTargetName: record.targetName,
      identity: record.identity
    ) {
      try fileSystem.moveExclusively(
        fromParent: record.targetURL.deletingLastPathComponent(),
        rawName: record.targetName,
        to: record.temporaryURL
      )
      try await journal.write(record.updating(phase: .temporary))
      try fileSystem.moveExclusively(from: record.temporaryURL, to: record.originalURL)
    } else {
      return false
    }
    return try fileSystem.hasIdentity(record.identity, at: record.originalURL)
  }

  func finish(_ record: RenameRecoveryRecord) async throws {
    try await journal.write(record)
    let verified =
      record.phase == .completed
      ? try fileSystem.isVerifiedTarget(
        record.targetURL,
        rawTargetName: record.targetName,
        identity: record.identity
      )
      : try fileSystem.hasIdentity(record.identity, at: record.originalURL)
    guard verified else { throw RenameFileSystemError.verificationFailed(record.targetURL) }
    try await journal.remove(operationID: record.operationID)
  }
}
