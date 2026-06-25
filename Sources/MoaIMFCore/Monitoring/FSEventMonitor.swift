import CoreServices
import Foundation

public struct FileSystemEvent: Equatable, Sendable {
  public let root: URL
  public let url: URL
  public let mustScanSubdirectories: Bool
  public let isSelfEvent: Bool

  public init(
    root: URL,
    url: URL,
    mustScanSubdirectories: Bool = false,
    isSelfEvent: Bool = false
  ) {
    self.root = root
    self.url = url
    self.mustScanSubdirectories = mustScanSubdirectories
    self.isSelfEvent = isSelfEvent
  }
}

public protocol EventMonitoring: Sendable {
  func start(
    roots: [URL],
    handler: @escaping @Sendable ([FileSystemEvent]) -> Void
  ) throws
  func stop()
}

public enum FSEventMonitorError: Error, Sendable {
  case streamCreationFailed
  case streamStartFailed
}

public final class FSEventMonitor: EventMonitoring, @unchecked Sendable {
  private final class CallbackBox {
    let roots: [URL]
    let handler: @Sendable ([FileSystemEvent]) -> Void

    init(roots: [URL], handler: @escaping @Sendable ([FileSystemEvent]) -> Void) {
      self.roots = roots
      self.handler = handler
    }
  }

  private let lock = NSLock()
  private let queue = DispatchQueue(label: "com.charliehotel.MoaIMF.fsevents")
  private var stream: FSEventStreamRef?
  private var callbackPointer: UnsafeMutableRawPointer?

  public init() {}

  deinit {
    stop()
  }

  public func start(
    roots: [URL],
    handler: @escaping @Sendable ([FileSystemEvent]) -> Void
  ) throws {
    stop()
    guard !roots.isEmpty else { return }
    let ownedRoots = roots.map(\.standardizedFileURL).sorted { $0.path < $1.path }
    let box = CallbackBox(roots: ownedRoots, handler: handler)
    let pointer = Unmanaged.passRetained(box).toOpaque()
    var context = FSEventStreamContext(
      version: 0,
      info: pointer,
      retain: nil,
      release: nil,
      copyDescription: nil
    )
    let flags = FSEventStreamCreateFlags(
      kFSEventStreamCreateFlagUseCFTypes
        | kFSEventStreamCreateFlagWatchRoot
        | kFSEventStreamCreateFlagIgnoreSelf
        | kFSEventStreamCreateFlagFileEvents
    )
    guard
      let created = FSEventStreamCreate(
        nil,
        Self.callback,
        &context,
        ownedRoots.map(\.path) as CFArray,
        FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
        1,
        flags
      )
    else {
      Unmanaged<CallbackBox>.fromOpaque(pointer).release()
      throw FSEventMonitorError.streamCreationFailed
    }
    FSEventStreamSetDispatchQueue(created, queue)
    guard FSEventStreamStart(created) else {
      FSEventStreamInvalidate(created)
      FSEventStreamRelease(created)
      Unmanaged<CallbackBox>.fromOpaque(pointer).release()
      throw FSEventMonitorError.streamStartFailed
    }
    lock.withLock {
      stream = created
      callbackPointer = pointer
    }
  }

  public func stop() {
    let state = lock.withLock { () -> (FSEventStreamRef?, UnsafeMutableRawPointer?) in
      let state = (stream, callbackPointer)
      stream = nil
      callbackPointer = nil
      return state
    }
    if let stream = state.0 {
      FSEventStreamStop(stream)
      FSEventStreamInvalidate(stream)
      FSEventStreamRelease(stream)
    }
    if let pointer = state.1 {
      Unmanaged<CallbackBox>.fromOpaque(pointer).release()
    }
  }

  private static let callback: FSEventStreamCallback = {
    _, info, count, eventPaths, eventFlags, _ in
    guard let info else { return }
    let box = Unmanaged<CallbackBox>.fromOpaque(info).takeUnretainedValue()
    let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue()
    var events: [FileSystemEvent] = []
    events.reserveCapacity(count)
    for index in 0..<count {
      guard let value = CFArrayGetValueAtIndex(paths, index) else { continue }
      let cfPath: CFString = unsafeBitCast(value, to: CFString.self)
      let url = URL(fileURLWithPath: cfPath as String)
      let root = box.roots
        .filter { url.path == $0.path || url.path.hasPrefix($0.path + "/") }
        .max { $0.path.count < $1.path.count }
      guard let root else { continue }
      let flags = eventFlags[index]
      events.append(
        FileSystemEvent(
          root: root,
          url: url,
          mustScanSubdirectories: flags
            & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0,
          isSelfEvent: flags & FSEventStreamEventFlags(kFSEventStreamEventFlagOwnEvent) != 0
        )
      )
    }
    if !events.isEmpty { box.handler(events) }
  }
}
