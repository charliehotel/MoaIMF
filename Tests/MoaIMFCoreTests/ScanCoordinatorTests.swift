import Foundation
import XCTest

@testable import MoaIMFCore

final class ScanCoordinatorTests: XCTestCase {
  func testDebouncesMultipleEventsIntoOnePathScan() async throws {
    let fixture = CoordinatorFixture()
    await fixture.startAndClearInitialScan()

    fixture.eventMonitor.send([
      FileSystemEvent(root: fixture.root, url: fixture.root.appendingPathComponent("a")),
      FileSystemEvent(root: fixture.root, url: fixture.root.appendingPathComponent("b")),
    ])
    try await fixture.sleeper.resume(.debounce)
    try await fixture.service.waitForRequestCount(1)
    let requests = await fixture.service.requests

    XCTAssertEqual(requests.count, 1)
    guard case .paths(let paths) = requests[0].scope else {
      return XCTFail("Expected path scan")
    }
    XCTAssertEqual(paths.count, 2)
  }

  func testMustScanSubdirectoriesRequestsFullRootScanAndSelfEventsAreIgnored() async throws {
    let fixture = CoordinatorFixture()
    await fixture.startAndClearInitialScan()

    fixture.eventMonitor.send([
      FileSystemEvent(root: fixture.root, url: fixture.root, isSelfEvent: true),
      FileSystemEvent(root: fixture.root, url: fixture.root, mustScanSubdirectories: true),
    ])
    try await fixture.sleeper.resume(.debounce)
    try await fixture.service.waitForRequestCount(1)
    let requests = await fixture.service.requests

    XCTAssertEqual(requests.map(\.scope), [.full])
  }

  func testPauseCancelsScheduledWorkAndResumeReconciles() async throws {
    let fixture = CoordinatorFixture()
    await fixture.startAndClearInitialScan()
    fixture.eventMonitor.send([FileSystemEvent(root: fixture.root, url: fixture.root)])

    await fixture.coordinator.pause()
    await fixture.coordinator.resume()
    try await fixture.service.waitForRequestCount(1)
    let requests = await fixture.service.requests

    XCTAssertEqual(requests.map(\.scope), [.full])
  }

  func testRuleChangeSchedulesImmediateReconciliation() async throws {
    let fixture = CoordinatorFixture()
    await fixture.startAndClearInitialScan()

    await fixture.coordinator.stabilityRulesDidChange()
    try await fixture.service.waitForRequestCount(1)
    let requests = await fixture.service.requests

    XCTAssertEqual(requests.map(\.scope), [.full])
  }

  func testAutomaticReconciliationCarriesPerRootExistingIdentityExclusions() async throws {
    let fixture = CoordinatorFixture()
    let excluded = FileIdentity(volume: "volume", resource: "existing")

    await fixture.coordinator.updateRoots(
      [fixture.root],
      excludedIdentitiesByRoot: [fixture.root: [excluded]]
    )
    await fixture.coordinator.start()
    try await fixture.service.waitForRequestCount(1)
    let requests = await fixture.service.requests

    XCTAssertEqual(requests.first?.excludedIdentities, [excluded])
  }

  func testPendingCandidatesAreRecheckedAfterDelay() async throws {
    let fixture = CoordinatorFixture()
    let identity = FileIdentity(volume: "volume", resource: "pending")
    await fixture.service.setResults([
      ScanServiceResult(pendingIdentities: [identity]),
      ScanServiceResult(),
    ])
    await fixture.coordinator.start()
    try await fixture.service.waitForRequestCount(1)

    try await fixture.sleeper.resume(.pendingRecheck)
    try await fixture.service.waitForRequestCount(2)
    let requests = await fixture.service.requests

    XCTAssertEqual(requests[1].scope, .candidates([identity]))
  }

  func testManualAndEventScansRemainSerialized() async throws {
    let fixture = CoordinatorFixture()
    await fixture.startAndClearInitialScan()
    await fixture.service.setBlocked(true)

    await fixture.coordinator.manualScan(root: fixture.root)
    fixture.eventMonitor.send([FileSystemEvent(root: fixture.root, url: fixture.root)])
    try await fixture.sleeper.resume(.debounce)
    try await fixture.service.waitForRequestCount(1)
    let firstMaximum = await fixture.service.maximumConcurrentScans
    XCTAssertEqual(firstMaximum, 1)

    await fixture.service.releaseOne()
    try await fixture.service.waitForRequestCount(2)
    let secondMaximum = await fixture.service.maximumConcurrentScans
    XCTAssertEqual(secondMaximum, 1)
    await fixture.service.releaseOne()
  }
}

private final class CoordinatorFixture {
  let root = URL(fileURLWithPath: "/watched", isDirectory: true)
  let eventMonitor = FakeEventMonitor()
  let volumeMonitor = FakeVolumeMonitor()
  let sleeper = FakeCoordinatorSleeper()
  let service = FakeScanService()
  let coordinator: ScanCoordinator

  init() {
    coordinator = ScanCoordinator(
      roots: [root],
      eventMonitor: eventMonitor,
      volumeMonitor: volumeMonitor,
      scanService: service,
      sleeper: sleeper
    )
  }

  func startAndClearInitialScan() async {
    await coordinator.start()
    try? await service.waitForRequestCount(1)
    await service.reset()
  }
}

private final class FakeEventMonitor: EventMonitoring, @unchecked Sendable {
  private let lock = NSLock()
  private var handler: (@Sendable ([FileSystemEvent]) -> Void)?

  func start(roots: [URL], handler: @escaping @Sendable ([FileSystemEvent]) -> Void) throws {
    lock.withLock { self.handler = handler }
  }

  func stop() {
    lock.withLock { handler = nil }
  }

  func send(_ events: [FileSystemEvent]) {
    lock.withLock { handler }?(events)
  }
}

private final class FakeVolumeMonitor: VolumeMonitoring, @unchecked Sendable {
  private let lock = NSLock()
  private var handler: (@Sendable (VolumeEvent) -> Void)?

  func start(handler: @escaping @Sendable (VolumeEvent) -> Void) {
    lock.withLock { self.handler = handler }
  }

  func stop() {
    lock.withLock { handler = nil }
  }
}

private actor FakeScanService: ScanServicing {
  private(set) var requests: [ScanRequest] = []
  private(set) var maximumConcurrentScans = 0
  private var concurrentScans = 0
  private var results: [ScanServiceResult] = []
  private var blocked = false
  private var releases: [CheckedContinuation<Void, Never>] = []

  func scan(_ request: ScanRequest) async throws -> ScanServiceResult {
    requests.append(request)
    concurrentScans += 1
    maximumConcurrentScans = max(maximumConcurrentScans, concurrentScans)
    if blocked {
      await withCheckedContinuation { releases.append($0) }
    }
    concurrentScans -= 1
    return results.isEmpty ? ScanServiceResult() : results.removeFirst()
  }

  func setResults(_ results: [ScanServiceResult]) {
    self.results = results
  }

  func setBlocked(_ blocked: Bool) {
    self.blocked = blocked
  }

  func releaseOne() {
    guard !releases.isEmpty else { return }
    releases.removeFirst().resume()
  }

  func reset() {
    requests = []
    maximumConcurrentScans = 0
  }

  func waitForRequestCount(_ count: Int) async throws {
    for _ in 0..<1_000 {
      if requests.count >= count { return }
      await Task.yield()
    }
    throw CoordinatorTestError.timeout
  }
}

private actor FakeCoordinatorSleeper: CoordinatorSleeping {
  private struct Waiter {
    let id: UUID
    let purpose: CoordinatorDelay
    let continuation: CheckedContinuation<Void, Error>
  }

  private var waiters: [Waiter] = []

  func sleep(for purpose: CoordinatorDelay) async throws {
    let id = UUID()
    try await withTaskCancellationHandler {
      try await withCheckedThrowingContinuation { continuation in
        waiters.append(Waiter(id: id, purpose: purpose, continuation: continuation))
      }
    } onCancel: {
      Task { await self.cancel(id: id) }
    }
  }

  func resume(_ purpose: CoordinatorDelay) async throws {
    for _ in 0..<1_000 {
      if let index = waiters.firstIndex(where: { $0.purpose == purpose }) {
        waiters.remove(at: index).continuation.resume()
        return
      }
      await Task.yield()
    }
    throw CoordinatorTestError.missingWaiter
  }

  private func cancel(id: UUID) {
    guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
    waiters.remove(at: index).continuation.resume(throwing: CancellationError())
  }
}

private enum CoordinatorTestError: Error {
  case timeout
  case missingWaiter
}
