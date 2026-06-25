import Foundation

public enum ScanScope: Equatable, Sendable {
  case full
  case paths(Set<URL>)
  case candidates(Set<FileIdentity>)
  case manualPreview
  case manualApply(Set<FileIdentity>)
}

public struct ScanRequest: Equatable, Sendable {
  public let root: URL
  public let scope: ScanScope
  public let excludedIdentities: Set<FileIdentity>

  public init(
    root: URL,
    scope: ScanScope,
    excludedIdentities: Set<FileIdentity> = []
  ) {
    self.root = root
    self.scope = scope
    self.excludedIdentities = excludedIdentities
  }
}

public struct ScanServiceResult: Equatable, Sendable {
  public let summary: ScanContentSummary
  public let pendingIdentities: Set<FileIdentity>
  public let plan: NormalizationPlan
  public let outcomes: [RenameOutcome]
  public let deferredIdentities: Set<FileIdentity>

  public init(
    summary: ScanContentSummary = ScanContentSummary(),
    pendingIdentities: Set<FileIdentity> = [],
    plan: NormalizationPlan = NormalizationPlan(candidates: [], collisions: []),
    outcomes: [RenameOutcome] = [],
    deferredIdentities: Set<FileIdentity> = []
  ) {
    self.summary = summary
    self.pendingIdentities = pendingIdentities
    self.plan = plan
    self.outcomes = outcomes
    self.deferredIdentities = deferredIdentities
  }
}

public struct ScanContentSummary: Equatable, Sendable {
  public let totalEntryCount: Int
  public let nfcEntryCount: Int
  public let nonNFCEntryCount: Int

  public init(totalEntryCount: Int = 0, nfcEntryCount: Int = 0, nonNFCEntryCount: Int = 0) {
    self.totalEntryCount = totalEntryCount
    self.nfcEntryCount = nfcEntryCount
    self.nonNFCEntryCount = nonNFCEntryCount
  }
}

public protocol ScanServicing: Sendable {
  func scan(_ request: ScanRequest) async throws -> ScanServiceResult
}

public enum CoordinatorDelay: Equatable, Sendable {
  case debounce
  case pendingRecheck
  case reconciliation
}

public protocol CoordinatorSleeping: Sendable {
  func sleep(for purpose: CoordinatorDelay) async throws
}

public struct ContinuousCoordinatorSleeper: CoordinatorSleeping {
  public init() {}

  public func sleep(for purpose: CoordinatorDelay) async throws {
    switch purpose {
    case .debounce:
      try await Task.sleep(for: .seconds(1))
    case .pendingRecheck:
      try await Task.sleep(for: .seconds(30))
    case .reconciliation:
      try await Task.sleep(for: .seconds(6 * 60 * 60))
    }
  }
}

public actor ScanCoordinator {
  var roots: Set<URL>
  var excludedIdentitiesByRoot: [URL: Set<FileIdentity>] = [:]
  private let eventMonitor: any EventMonitoring
  private let volumeMonitor: any VolumeMonitoring
  let scanService: any ScanServicing
  let sleeper: any CoordinatorSleeping
  var isPaused = true
  var pendingPaths: [URL: Set<URL>] = [:]
  var pendingFullRoots: Set<URL> = []
  var debounceTask: Task<Void, Never>?
  var reconciliationTask: Task<Void, Never>?
  var recheckTasks: [URL: Task<Void, Never>] = [:]
  var requestQueue: [ScanRequest] = []
  var isDraining = false
  public internal(set) var lastError: String?

  public init(
    roots: Set<URL>,
    eventMonitor: any EventMonitoring,
    volumeMonitor: any VolumeMonitoring,
    scanService: any ScanServicing,
    sleeper: any CoordinatorSleeping = ContinuousCoordinatorSleeper()
  ) {
    self.roots = roots
    self.eventMonitor = eventMonitor
    self.volumeMonitor = volumeMonitor
    self.scanService = scanService
    self.sleeper = sleeper
  }

  public func start() {
    guard isPaused else { return }
    resume()
  }

  public func pause() {
    isPaused = true
    eventMonitor.stop()
    volumeMonitor.stop()
    debounceTask?.cancel()
    reconciliationTask?.cancel()
    for task in recheckTasks.values { task.cancel() }
    debounceTask = nil
    reconciliationTask = nil
    recheckTasks = [:]
    pendingPaths = [:]
    pendingFullRoots = []
  }

  public func resume() {
    guard isPaused else { return }
    isPaused = false
    startMonitors()
    enqueueFullReconciliation()
    scheduleReconciliation()
  }

  public func updateRoots(
    _ roots: Set<URL>,
    excludedIdentitiesByRoot: [URL: Set<FileIdentity>] = [:]
  ) {
    self.roots = roots
    self.excludedIdentitiesByRoot = excludedIdentitiesByRoot.filter { roots.contains($0.key) }
    if !isPaused {
      startMonitors()
      enqueueFullReconciliation()
    }
  }

  public func manualScan(root: URL) {
    enqueue(ScanRequest(root: root, scope: .manualPreview))
  }

  public func stabilityRulesDidChange() {
    guard !isPaused else { return }
    debounceTask?.cancel()
    pendingPaths = [:]
    pendingFullRoots = []
    enqueueFullReconciliation()
  }

  func receive(_ events: [FileSystemEvent]) {
    guard !isPaused else { return }
    for event in events where !event.isSelfEvent {
      if event.mustScanSubdirectories {
        pendingFullRoots.insert(event.root)
        pendingPaths[event.root] = nil
      } else if !pendingFullRoots.contains(event.root) {
        pendingPaths[event.root, default: []].insert(event.url)
      }
    }
    scheduleDebounce()
  }

  private func startMonitors() {
    eventMonitor.stop()
    do {
      try eventMonitor.start(roots: Array(roots)) { [weak self] events in
        guard let self else { return }
        Task { await self.receive(events) }
      }
    } catch {
      lastError = String(describing: error)
    }
    volumeMonitor.stop()
    volumeMonitor.start { [weak self] event in
      guard let self else { return }
      Task { await self.receive(event) }
    }
  }

  private func receive(_ event: VolumeEvent) {
    guard !isPaused else { return }
    startMonitors()
    if event.kind != .unmounted {
      for root in roots where root.path.hasPrefix(event.volumeURL.path) {
        enqueueAutomatic(root: root, scope: .full)
      }
    }
  }

  func enqueueAutomatic(root: URL, scope: ScanScope) {
    enqueue(
      ScanRequest(
        root: root,
        scope: scope,
        excludedIdentities: excludedIdentitiesByRoot[root] ?? []
      ))
  }

}
