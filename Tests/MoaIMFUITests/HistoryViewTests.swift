import MoaIMFCore
import XCTest

@testable import MoaIMFUI

final class HistoryViewTests: XCTestCase {
  func testDateScopeFiltersExpectedPeriods() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
    let now = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 6, day: 24, hour: 12))
    )
    let sameDay = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 6, day: 24, hour: 1))
    )
    let yesterday = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 6, day: 23, hour: 23))
    )
    let eightDaysAgo = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 6, day: 16, hour: 11))
    )

    XCTAssertTrue(HistoryDateScope.today.contains(sameDay, now: now, calendar: calendar))
    XCTAssertFalse(HistoryDateScope.today.contains(yesterday, now: now, calendar: calendar))
    XCTAssertTrue(HistoryDateScope.sevenDays.contains(yesterday, now: now, calendar: calendar))
    XCTAssertFalse(HistoryDateScope.sevenDays.contains(eightDaysAgo, now: now, calendar: calendar))
    XCTAssertTrue(HistoryDateScope.thirtyDays.contains(eightDaysAgo, now: now, calendar: calendar))
    XCTAssertTrue(HistoryDateScope.all.contains(.distantPast, now: now, calendar: calendar))
  }

  func testHistoryTypeFilterMatchesExpectedEventKinds() {
    XCTAssertTrue(HistoryFilter.all.contains(.renamed))
    XCTAssertTrue(HistoryFilter.all.contains(.collision))
    XCTAssertTrue(HistoryFilter.renamed.contains(.renamed))
    XCTAssertFalse(HistoryFilter.renamed.contains(.collision))
    XCTAssertTrue(HistoryFilter.collision.contains(.collision))
    XCTAssertTrue(HistoryFilter.permission.contains(.permission))
    XCTAssertTrue(HistoryFilter.error.contains(.error))
    XCTAssertTrue(HistoryFilter.error.contains(.disconnected))
    XCTAssertTrue(HistoryFilter.error.contains(.unsupportedFilesystem))
    XCTAssertFalse(HistoryFilter.error.contains(.renamed))
  }

  func testHistorySearchMatchesTitleReasonAndCanonicalPathVariants() {
    let root = URL(fileURLWithPath: "/Users/example/Downloads")
    let event = HistoryEvent(
      timestamp: Date(),
      kind: .renamed,
      rootIdentifier: root.path,
      previousURL: root.appendingPathComponent("한글.txt"),
      resultingURL: root.appendingPathComponent("한글.txt"),
      reason: "fallback rename completed"
    )

    XCTAssertTrue(HistorySearch.matches(event, query: "수정", title: "파일명 수정 완료"))
    XCTAssertTrue(HistorySearch.matches(event, query: "downloads", title: "파일명 수정 완료"))
    XCTAssertTrue(HistorySearch.matches(event, query: "fallback", title: "파일명 수정 완료"))
    XCTAssertTrue(HistorySearch.matches(event, query: "한글", title: "파일명 수정 완료"))
    XCTAssertTrue(HistorySearch.matches(event, query: "한글", title: "파일명 수정 완료"))
    XCTAssertTrue(HistorySearch.matches(event, query: "   ", title: "파일명 수정 완료"))
    XCTAssertFalse(HistorySearch.matches(event, query: "없는값", title: "파일명 수정 완료"))
  }
}
