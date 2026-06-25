import Foundation

public actor StabilityRuleStore {
  private struct Payload: Codable, Sendable {
    let version: Int
    let rules: [StabilityExclusionRule]
  }

  private let fileURL: URL

  public init(fileURL: URL) {
    self.fileURL = fileURL
  }

  public func allRules() throws -> [StabilityExclusionRule] {
    StabilityExclusionMatcher.builtInRules + (try loadUserRules())
  }

  @discardableResult
  public func add(kind: StabilityRuleKind, pattern: String) throws -> StabilityExclusionRule {
    try StabilityExclusionMatcher.validate(kind: kind, pattern: pattern)
    var rules = try loadUserRules()
    let normalizedPattern = UnicodeNormalizer.nfc(pattern)
    let mergedRules = StabilityExclusionMatcher.builtInRules + rules
    guard
      !mergedRules.contains(where: {
        $0.kind == kind && UnicodeNormalizer.nfc($0.pattern) == normalizedPattern
      })
    else {
      throw StabilityRuleError.duplicateRule
    }
    let rule = StabilityExclusionRule(
      id: UUID().uuidString,
      kind: kind,
      pattern: pattern,
      source: .user
    )
    rules.append(rule)
    try persist(rules)
    return rule
  }

  public func remove(id: String) throws {
    if StabilityExclusionMatcher.builtInRules.contains(where: { $0.id == id }) {
      throw StabilityRuleError.builtInRule
    }
    var rules = try loadUserRules()
    rules.removeAll { $0.id == id }
    try persist(rules)
  }

  private func loadUserRules() throws -> [StabilityExclusionRule] {
    let data: Data
    do {
      data = try Data(contentsOf: fileURL)
    } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
      return []
    }
    let payload = try JSONDecoder().decode(Payload.self, from: data)
    guard payload.version == 1 else { return [] }
    for rule in payload.rules {
      try StabilityExclusionMatcher.validate(kind: rule.kind, pattern: rule.pattern)
      if rule.source != .user { throw StabilityRuleError.builtInRule }
    }
    return payload.rules
  }

  private func persist(_ rules: [StabilityExclusionRule]) throws {
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    try encoder.encode(Payload(version: 1, rules: rules)).write(to: fileURL, options: .atomic)
  }
}
