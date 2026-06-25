import Foundation
import UserNotifications

public enum SystemNotificationEvent: String, Equatable, Sendable {
  case collision
  case permissionLost
  case disconnectedVolume
  case unsupportedFilesystem
  case repeatedError
}

public struct SystemNotification: Equatable, Sendable {
  public let event: SystemNotificationEvent
  public let title: String
  public let body: String

  public init(event: SystemNotificationEvent, title: String, body: String) {
    self.event = event
    self.title = title
    self.body = body
  }
}

@MainActor
public protocol NotificationCenterService: AnyObject {
  func requestAuthorization() async throws -> Bool
  func deliver(_ notification: SystemNotification) async throws
}

@MainActor
public final class SystemNotifier {
  private let center: any NotificationCenterService
  private var didRequestAuthorization = false
  private var isAuthorized = false

  public init(center: any NotificationCenterService = UserNotificationCenterService()) {
    self.center = center
  }

  public func setEnabled(_ enabled: Bool) async {
    guard enabled else { return }
    await requestAuthorizationIfNeeded()
  }

  public func notify(_ event: SystemNotificationEvent) async {
    await requestAuthorizationIfNeeded()
    guard isAuthorized else { return }
    try? await center.deliver(Self.notification(for: event))
  }

  public func recordSuccessfulRename() async {}

  private func requestAuthorizationIfNeeded() async {
    guard !didRequestAuthorization else { return }
    didRequestAuthorization = true
    isAuthorized = (try? await center.requestAuthorization()) ?? false
  }

  private static func notification(for event: SystemNotificationEvent) -> SystemNotification {
    switch event {
    case .collision:
      SystemNotification(
        event: event,
        title: "MoaIMF",
        body: MoaIMFLocalization.text("alert.collision")
      )
    case .permissionLost:
      SystemNotification(
        event: event,
        title: "MoaIMF",
        body: MoaIMFLocalization.text("alert.permission")
      )
    case .disconnectedVolume:
      SystemNotification(
        event: event,
        title: "MoaIMF",
        body: MoaIMFLocalization.text("alert.disconnected")
      )
    case .unsupportedFilesystem:
      SystemNotification(
        event: event,
        title: "MoaIMF",
        body: MoaIMFLocalization.text("alert.unsupported")
      )
    case .repeatedError:
      SystemNotification(
        event: event,
        title: "MoaIMF",
        body: MoaIMFLocalization.text("alert.generic")
      )
    }
  }
}

@MainActor
public final class UserNotificationCenterService: NotificationCenterService {
  private let centerProvider: () -> UNUserNotificationCenter

  public init() {
    centerProvider = { UNUserNotificationCenter.current() }
  }

  public init(center: UNUserNotificationCenter) {
    centerProvider = { center }
  }

  public func requestAuthorization() async throws -> Bool {
    try await centerProvider().requestAuthorization(options: [.alert, .sound])
  }

  public func deliver(_ notification: SystemNotification) async throws {
    let content = UNMutableNotificationContent()
    content.title = notification.title
    content.body = notification.body
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "moaimf.\(notification.event.rawValue).\(UUID().uuidString)",
      content: content,
      trigger: nil
    )
    try await centerProvider().add(request)
  }
}
