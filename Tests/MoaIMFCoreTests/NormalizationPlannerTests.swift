import Foundation
import XCTest

@testable import MoaIMFCore

final class NormalizationPlannerTests: XCTestCase {
  private let planner = NormalizationPlanner()

  func testPlansSingleDecomposedName() {
    let plan = planner.plan(entries: [entry("가.txt")], caseSensitive: false)

    XCTAssertEqual(plan.candidates.map(\.targetName), ["가.txt"])
    XCTAssertTrue(plan.collisions.isEmpty)
  }

  func testRejectsCanonicallyEquivalentSiblingsAsCollision() {
    let plan = planner.plan(
      entries: [entry("가.txt"), entry("가.txt")],
      caseSensitive: false
    )

    XCTAssertTrue(plan.candidates.isEmpty)
    XCTAssertEqual(plan.collisions.first?.rawNames, ["가.txt", "가.txt"])
  }

  func testCaseInsensitiveVolumeGroupsCaseVariants() {
    let plan = planner.plan(
      entries: [entry("Report.txt"), entry("report.txt")],
      caseSensitive: false
    )

    XCTAssertTrue(plan.candidates.isEmpty)
    XCTAssertEqual(plan.collisions.first?.rawNames, ["Report.txt", "report.txt"])
  }

  func testCaseSensitiveVolumeKeepsCaseVariantsSeparate() {
    let plan = planner.plan(
      entries: [entry("Report.txt"), entry("report.txt")],
      caseSensitive: true
    )

    XCTAssertTrue(plan.candidates.isEmpty)
    XCTAssertTrue(plan.collisions.isEmpty)
  }

  func testSortsCandidatesDeepestFirstThenBySourcePath() {
    let root = URL(fileURLWithPath: "/fixture", isDirectory: true)
    let nested = root.appendingPathComponent("nested", isDirectory: true)
    let entries = [
      entry("나.txt", parent: root),
      entry("다.txt", parent: nested),
      entry("가.txt", parent: nested),
    ]

    let plan = planner.plan(entries: entries, caseSensitive: true)

    XCTAssertEqual(
      plan.candidates.map(\.source.path),
      ["/fixture/nested/가.txt", "/fixture/nested/다.txt", "/fixture/나.txt"]
    )
  }

  private func entry(
    _ name: String,
    parent: URL = URL(fileURLWithPath: "/fixture", isDirectory: true)
  ) -> SiblingEntry {
    SiblingEntry(
      identity: FileIdentity(volume: "test-volume", resource: parent.path + name),
      parent: parent,
      rawName: name,
      isDirectory: false
    )
  }
}
