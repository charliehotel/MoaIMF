import Foundation

public enum StabilityRuleKind: String, Codable, Sendable {
  case exactName
  case suffix
  case glob
}

public enum StabilityRuleSource: String, Codable, Sendable {
  case builtIn
  case user
}

public struct StabilityExclusionRule: Identifiable, Codable, Equatable, Sendable {
  public let id: String
  public let kind: StabilityRuleKind
  public let pattern: String
  public let source: StabilityRuleSource

  public init(id: String, kind: StabilityRuleKind, pattern: String, source: StabilityRuleSource) {
    self.id = id
    self.kind = kind
    self.pattern = pattern
    self.source = source
  }
}

public struct StabilityExclusionMatch: Equatable, Sendable {
  public let ruleID: String
  public let pattern: String

  public init(ruleID: String, pattern: String) {
    self.ruleID = ruleID
    self.pattern = pattern
  }
}

public enum StabilityRuleError: Error, Equatable, Sendable {
  case emptyPattern
  case patternTooLong
  case pathSeparator
  case nulCharacter
  case invalidSuffix
  case wildcardsNotAllowed
  case duplicateRule
  case builtInRule
}

public struct StabilityExclusionMatcher: Sendable {
  public static let builtInRules: [StabilityExclusionRule] = [
    StabilityExclusionRule(
      id: "builtin.crdownload",
      kind: .suffix,
      pattern: ".crdownload",
      source: .builtIn
    ),
    StabilityExclusionRule(
      id: "builtin.download",
      kind: .suffix,
      pattern: ".download",
      source: .builtIn
    ),
    StabilityExclusionRule(id: "builtin.part", kind: .suffix, pattern: ".part", source: .builtIn),
    StabilityExclusionRule(
      id: "builtin.partial",
      kind: .suffix,
      pattern: ".partial",
      source: .builtIn
    ),
    StabilityExclusionRule(id: "builtin.tmp", kind: .suffix, pattern: ".tmp", source: .builtIn),
  ]

  private let rules: [StabilityExclusionRule]

  public init(rules: [StabilityExclusionRule]) {
    self.rules = rules.sorted {
      let left = Self.kindOrder($0.kind)
      let right = Self.kindOrder($1.kind)
      return left == right ? $0.id < $1.id : left < right
    }
  }

  public func match(name: String, caseSensitive: Bool) -> StabilityExclusionMatch? {
    let candidate = comparable(name, caseSensitive: caseSensitive)
    for rule in rules {
      let pattern = comparable(rule.pattern, caseSensitive: caseSensitive)
      let matches: Bool
      switch rule.kind {
      case .exactName:
        matches = candidate == pattern
      case .suffix:
        matches = candidate.hasSuffix(pattern)
      case .glob:
        matches = globMatches(pattern: Array(pattern), value: Array(candidate))
      }
      if matches {
        return StabilityExclusionMatch(ruleID: rule.id, pattern: rule.pattern)
      }
    }
    return nil
  }

  public static func validate(kind: StabilityRuleKind, pattern: String) throws {
    guard !pattern.isEmpty else { throw StabilityRuleError.emptyPattern }
    guard pattern.count <= 255 else { throw StabilityRuleError.patternTooLong }
    guard !pattern.contains("/") else { throw StabilityRuleError.pathSeparator }
    guard !pattern.contains("\0") else { throw StabilityRuleError.nulCharacter }
    if kind == .suffix, !pattern.hasPrefix(".") {
      throw StabilityRuleError.invalidSuffix
    }
    if kind == .exactName, pattern.contains(where: { $0 == "*" || $0 == "?" }) {
      throw StabilityRuleError.wildcardsNotAllowed
    }
  }

  private func comparable(_ value: String, caseSensitive: Bool) -> String {
    let normalized = UnicodeNormalizer.nfc(value)
    return caseSensitive
      ? normalized
      : normalized.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
  }

  private func globMatches(pattern: [Character], value: [Character]) -> Bool {
    var matches = Array(
      repeating: Array(repeating: false, count: value.count + 1),
      count: pattern.count + 1
    )
    matches[0][0] = true
    if !pattern.isEmpty {
      for patternIndex in 1...pattern.count where pattern[patternIndex - 1] == "*" {
        matches[patternIndex][0] = matches[patternIndex - 1][0]
      }
    }
    if !pattern.isEmpty, !value.isEmpty {
      for patternIndex in 1...pattern.count {
        for valueIndex in 1...value.count {
          switch pattern[patternIndex - 1] {
          case "*":
            matches[patternIndex][valueIndex] =
              matches[patternIndex - 1][valueIndex] || matches[patternIndex][valueIndex - 1]
          case "?":
            matches[patternIndex][valueIndex] = matches[patternIndex - 1][valueIndex - 1]
          default:
            matches[patternIndex][valueIndex] =
              matches[patternIndex - 1][valueIndex - 1]
              && pattern[patternIndex - 1] == value[valueIndex - 1]
          }
        }
      }
    }
    return matches[pattern.count][value.count]
  }

  private static func kindOrder(_ kind: StabilityRuleKind) -> Int {
    switch kind {
    case .exactName: 0
    case .suffix: 1
    case .glob: 2
    }
  }
}
