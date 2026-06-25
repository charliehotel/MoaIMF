import Foundation

public struct NormalizationPlanner: Sendable {
  public init() {}

  public func plan(entries: [SiblingEntry], caseSensitive: Bool) -> NormalizationPlan {
    let groups = Dictionary(grouping: entries) {
      comparisonKey($0.rawName, caseSensitive: caseSensitive)
    }
    var candidates: [RenameCandidate] = []
    var collisions: [NormalizationCollision] = []

    for (key, siblings) in groups {
      if siblings.count > 1, let parent = siblings.first?.parent {
        collisions.append(
          NormalizationCollision(
            parent: parent,
            normalizedKey: key,
            rawNames: siblings.map(\.rawName).sorted(by: scalarPrecedes)
          )
        )
        continue
      }

      guard let entry = siblings.first, !UnicodeNormalizer.isNFC(entry.rawName) else {
        continue
      }
      candidates.append(
        RenameCandidate(
          identity: entry.identity,
          source: entry.parent.appendingPathComponent(
            entry.rawName, isDirectory: entry.isDirectory),
          targetName: UnicodeNormalizer.nfc(entry.rawName)
        )
      )
    }

    candidates.sort {
      let leftDepth = $0.source.pathComponents.count
      let rightDepth = $1.source.pathComponents.count
      return leftDepth == rightDepth
        ? scalarPrecedes($0.source.path, $1.source.path)
        : leftDepth > rightDepth
    }
    collisions.sort {
      if $0.parent.path != $1.parent.path {
        return scalarPrecedes($0.parent.path, $1.parent.path)
      }
      return scalarPrecedes($0.normalizedKey, $1.normalizedKey)
    }

    return NormalizationPlan(candidates: candidates, collisions: collisions)
  }

  private func comparisonKey(_ name: String, caseSensitive: Bool) -> String {
    let normalized = UnicodeNormalizer.nfc(name)
    return caseSensitive ? normalized : normalized.caseFoldedForFilesystem
  }

  private func scalarPrecedes(_ left: String, _ right: String) -> Bool {
    left.unicodeScalars.lexicographicallyPrecedes(right.unicodeScalars) {
      $0.value < $1.value
    }
  }
}

extension String {
  fileprivate var caseFoldedForFilesystem: String {
    folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
  }
}
