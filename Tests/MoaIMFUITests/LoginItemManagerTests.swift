import XCTest

@testable import MoaIMFUI

@MainActor
final class LoginItemManagerTests: XCTestCase {
  func testMapsEveryServiceStatus() {
    XCTAssertEqual(
      LoginItemManager(service: FakeLoginItemService(status: .enabled)).state, .enabled)
    XCTAssertEqual(
      LoginItemManager(service: FakeLoginItemService(status: .requiresApproval)).state,
      .requiresApproval
    )
    XCTAssertEqual(
      LoginItemManager(service: FakeLoginItemService(status: .disabled)).state, .disabled)
    XCTAssertEqual(
      LoginItemManager(service: FakeLoginItemService(status: .notFound)).state, .notFound)
  }

  func testEveryStateHasMenuStatusPresentation() {
    XCTAssertEqual(LoginItemState.enabled.menuLocalizationKey, "menu.loginStatus.enabled")
    XCTAssertEqual(LoginItemState.enabled.menuSystemImage, "checkmark.circle")
    XCTAssertEqual(
      LoginItemState.requiresApproval.menuLocalizationKey,
      "menu.loginStatus.requiresApproval"
    )
    XCTAssertEqual(LoginItemState.requiresApproval.menuSystemImage, "exclamationmark.triangle")
    XCTAssertEqual(LoginItemState.disabled.menuLocalizationKey, "menu.loginStatus.disabled")
    XCTAssertEqual(LoginItemState.disabled.menuSystemImage, "circle")
    XCTAssertEqual(LoginItemState.notFound.menuLocalizationKey, "menu.loginStatus.notFound")
    XCTAssertEqual(LoginItemState.notFound.menuSystemImage, "questionmark.circle")
  }

  func testEnablingRegistersAndRefreshesState() {
    let service = FakeLoginItemService(status: .disabled)
    let manager = LoginItemManager(service: service)

    manager.setEnabled(true)

    XCTAssertEqual(service.registerCallCount, 1)
    XCTAssertEqual(manager.state, .enabled)
    XCTAssertNil(manager.lastErrorDescription)
  }

  func testEnablingAlreadyRegisteredItemOnlyRefreshes() {
    let service = FakeLoginItemService(status: .enabled)
    let manager = LoginItemManager(service: service)

    manager.setEnabled(true)

    XCTAssertEqual(service.registerCallCount, 0)
    XCTAssertEqual(manager.state, .enabled)
  }

  func testDeniedRegistrationSurfacesApprovalStateWithoutThrowing() {
    let service = FakeLoginItemService(status: .disabled)
    service.registerResult = .failure(FakeLoginItemError.denied)
    service.statusAfterRegisterFailure = .requiresApproval
    let manager = LoginItemManager(service: service)

    manager.setEnabled(true)

    XCTAssertEqual(manager.state, .requiresApproval)
    XCTAssertNotNil(manager.lastErrorDescription)
  }

  func testDisablingUnregistersAndRefreshesState() {
    let service = FakeLoginItemService(status: .enabled)
    let manager = LoginItemManager(service: service)

    manager.setEnabled(false)

    XCTAssertEqual(service.unregisterCallCount, 1)
    XCTAssertEqual(manager.state, .disabled)
  }

  func testOpeningSettingsUsesInjectedService() {
    let service = FakeLoginItemService(status: .requiresApproval)
    let manager = LoginItemManager(service: service)

    manager.openSystemSettings()

    XCTAssertEqual(service.openSettingsCallCount, 1)
  }
}

@MainActor
private final class FakeLoginItemService: LoginItemService {
  var status: LoginItemServiceStatus
  var registerResult: Result<Void, Error> = .success(())
  var statusAfterRegisterFailure: LoginItemServiceStatus?
  private(set) var registerCallCount = 0
  private(set) var unregisterCallCount = 0
  private(set) var openSettingsCallCount = 0

  init(status: LoginItemServiceStatus) {
    self.status = status
  }

  func register() throws {
    registerCallCount += 1
    switch registerResult {
    case .success:
      status = .enabled
    case .failure(let error):
      if let statusAfterRegisterFailure {
        status = statusAfterRegisterFailure
      }
      throw error
    }
  }

  func unregister() throws {
    unregisterCallCount += 1
    status = .disabled
  }

  func openSystemSettings() {
    openSettingsCallCount += 1
  }
}

private enum FakeLoginItemError: Error {
  case denied
}
