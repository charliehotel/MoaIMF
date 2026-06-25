import XCTest

@testable import MoaIMFUI

@MainActor
final class SystemNotifierTests: XCTestCase {
  func testSuccessfulRenameDoesNotProduceNotification() async {
    let center = FakeNotificationCenter()
    let notifier = SystemNotifier(center: center)

    await notifier.recordSuccessfulRename()

    XCTAssertEqual(center.authorizationCallCount, 0)
    XCTAssertTrue(center.delivered.isEmpty)
  }

  func testFirstActionableFailureRequestsAuthorizationAndNotifies() async {
    let center = FakeNotificationCenter()
    let notifier = SystemNotifier(center: center)

    await notifier.notify(.collision)
    await notifier.notify(.permissionLost)

    XCTAssertEqual(center.authorizationCallCount, 1)
    XCTAssertEqual(center.delivered.map(\.event), [.collision, .permissionLost])
  }

  func testExplicitEnableRequestsAuthorizationOnce() async {
    let center = FakeNotificationCenter()
    let notifier = SystemNotifier(center: center)

    await notifier.setEnabled(true)
    await notifier.setEnabled(true)

    XCTAssertEqual(center.authorizationCallCount, 1)
  }
}

@MainActor
private final class FakeNotificationCenter: NotificationCenterService {
  var authorizationGranted = true
  private(set) var authorizationCallCount = 0
  private(set) var delivered: [SystemNotification] = []

  func requestAuthorization() async throws -> Bool {
    authorizationCallCount += 1
    return authorizationGranted
  }

  func deliver(_ notification: SystemNotification) async throws {
    delivered.append(notification)
  }
}
