import AppKit
import Foundation

public enum VolumeEventKind: Equatable, Sendable {
  case mounted
  case unmounted
  case renamed
}

public struct VolumeEvent: Equatable, Sendable {
  public let kind: VolumeEventKind
  public let volumeURL: URL

  public init(kind: VolumeEventKind, volumeURL: URL) {
    self.kind = kind
    self.volumeURL = volumeURL
  }
}

public protocol VolumeMonitoring: Sendable {
  func start(handler: @escaping @Sendable (VolumeEvent) -> Void)
  func stop()
}

public final class VolumeMonitor: VolumeMonitoring, @unchecked Sendable {
  private let lock = NSLock()
  private var observers: [NSObjectProtocol] = []

  public init() {}

  deinit {
    stop()
  }

  public func start(handler: @escaping @Sendable (VolumeEvent) -> Void) {
    stop()
    let center = NSWorkspace.shared.notificationCenter
    let registrations: [(Notification.Name, VolumeEventKind)] = [
      (NSWorkspace.didMountNotification, .mounted),
      (NSWorkspace.didUnmountNotification, .unmounted),
      (NSWorkspace.didRenameVolumeNotification, .renamed),
    ]
    let tokens = registrations.map { name, kind in
      center.addObserver(forName: name, object: nil, queue: nil) { notification in
        guard
          let url = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL
        else {
          return
        }
        handler(VolumeEvent(kind: kind, volumeURL: url.standardizedFileURL))
      }
    }
    lock.withLock { observers = tokens }
  }

  public func stop() {
    let tokens = lock.withLock { () -> [NSObjectProtocol] in
      let tokens = observers
      observers = []
      return tokens
    }
    let center = NSWorkspace.shared.notificationCenter
    for token in tokens { center.removeObserver(token) }
  }
}
