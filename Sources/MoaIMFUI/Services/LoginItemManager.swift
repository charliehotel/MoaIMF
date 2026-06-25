import Combine
import ServiceManagement

public enum LoginItemState: Equatable, Sendable {
  case enabled
  case requiresApproval
  case disabled
  case notFound
}

extension LoginItemState {
  var menuLocalizationKey: String {
    switch self {
    case .enabled: "menu.loginStatus.enabled"
    case .requiresApproval: "menu.loginStatus.requiresApproval"
    case .disabled: "menu.loginStatus.disabled"
    case .notFound: "menu.loginStatus.notFound"
    }
  }

  var menuSystemImage: String {
    switch self {
    case .enabled: "checkmark.circle"
    case .requiresApproval: "exclamationmark.triangle"
    case .disabled: "circle"
    case .notFound: "questionmark.circle"
    }
  }
}

public enum LoginItemServiceStatus: Equatable, Sendable {
  case enabled
  case requiresApproval
  case disabled
  case notFound
}

@MainActor
public protocol LoginItemService: AnyObject {
  var status: LoginItemServiceStatus { get }
  func register() throws
  func unregister() throws
  func openSystemSettings()
}

@MainActor
public final class LoginItemManager: ObservableObject {
  @Published public private(set) var state: LoginItemState
  @Published public private(set) var lastErrorDescription: String?

  private let service: any LoginItemService

  public init(service: any LoginItemService = MainAppLoginItemService()) {
    self.service = service
    state = Self.map(service.status)
  }

  public func refresh() {
    state = Self.map(service.status)
  }

  public func setEnabled(_ enabled: Bool) {
    lastErrorDescription = nil
    do {
      if enabled {
        guard service.status != .enabled else {
          refresh()
          return
        }
        try service.register()
      } else {
        guard service.status != .disabled, service.status != .notFound else {
          refresh()
          return
        }
        try service.unregister()
      }
    } catch {
      lastErrorDescription = error.localizedDescription
    }
    refresh()
  }

  public func openSystemSettings() {
    service.openSystemSettings()
  }

  private static func map(_ status: LoginItemServiceStatus) -> LoginItemState {
    switch status {
    case .enabled: .enabled
    case .requiresApproval: .requiresApproval
    case .disabled: .disabled
    case .notFound: .notFound
    }
  }
}

@MainActor
public final class MainAppLoginItemService: LoginItemService {
  private let appService: SMAppService

  public init(appService: SMAppService = .mainApp) {
    self.appService = appService
  }

  public var status: LoginItemServiceStatus {
    switch appService.status {
    case .enabled: .enabled
    case .requiresApproval: .requiresApproval
    case .notRegistered: .disabled
    case .notFound: .notFound
    @unknown default: .disabled
    }
  }

  public func register() throws {
    try appService.register()
  }

  public func unregister() throws {
    try appService.unregister()
  }

  public func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
