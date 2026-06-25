import Foundation
import MoaIMFCore

@MainActor
public protocol AppDataServicing: AnyObject {
  func loadFolders() async throws -> [AppFolder]
  func loadRules() async throws -> [StabilityExclusionRule]
  func loadHistory() async throws -> [HistoryEvent]
  func addFolder(
    url: URL,
    mode: WatchedFolderNormalizationMode
  ) async throws -> AppFolder
  func removeFolder(id: UUID) async throws
  func setFolderEnabled(id: UUID, enabled: Bool) async throws
  func reselectFolder(id: UUID, url: URL) async throws
  func addRule(kind: StabilityRuleKind, pattern: String) async throws -> StabilityExclusionRule
  func removeRule(id: String) async throws
  func shutdown() async
}

@MainActor
public protocol AppScanControlling: AnyObject {
  func start(roots: [URL: Set<FileIdentity>]) async
  func updateRoots(_ roots: [URL: Set<FileIdentity>]) async
  func preview(root: URL) async throws -> ScanServiceResult
  func apply(root: URL, identities: Set<FileIdentity>) async throws -> ScanServiceResult
  func pause() async
  func resume() async
  func rulesDidChange() async
  func shutdown() async
}

@MainActor
public protocol AppPreferencesStoring: AnyObject {
  var isPaused: Bool { get set }
  var language: MoaIMFLanguage { get set }
  var isLaunchHintHidden: Bool { get set }
}

@MainActor
public final class UserDefaultsAppPreferences: AppPreferencesStoring {
  private let defaults: UserDefaults
  private let pausedKey = "watching.isPaused"
  private let languageKey = "ui.language"
  private let launchHintHiddenKey = "ui.launchHintHidden"

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public var isPaused: Bool {
    get { defaults.bool(forKey: pausedKey) }
    set { defaults.set(newValue, forKey: pausedKey) }
  }

  public var language: MoaIMFLanguage {
    get {
      guard
        let rawValue = defaults.string(forKey: languageKey),
        let language = MoaIMFLanguage(rawValue: rawValue)
      else {
        return .system
      }
      return language
    }
    set {
      defaults.set(newValue.rawValue, forKey: languageKey)
    }
  }

  public var isLaunchHintHidden: Bool {
    get { defaults.bool(forKey: launchHintHiddenKey) }
    set { defaults.set(newValue, forKey: launchHintHiddenKey) }
  }
}

@MainActor
public final class CoordinatorScanController: AppScanControlling {
  private let coordinator: ScanCoordinator
  private let scanService: any ScanServicing

  public init(coordinator: ScanCoordinator, scanService: any ScanServicing) {
    self.coordinator = coordinator
    self.scanService = scanService
  }

  public func start(roots: [URL: Set<FileIdentity>]) async {
    await coordinator.updateRoots(
      Set(roots.keys),
      excludedIdentitiesByRoot: roots
    )
    await coordinator.start()
  }

  public func updateRoots(_ roots: [URL: Set<FileIdentity>]) async {
    await coordinator.updateRoots(
      Set(roots.keys),
      excludedIdentitiesByRoot: roots
    )
  }

  public func preview(root: URL) async throws -> ScanServiceResult {
    try await scanService.scan(ScanRequest(root: root, scope: .manualPreview))
  }

  public func apply(root: URL, identities: Set<FileIdentity>) async throws -> ScanServiceResult {
    try await scanService.scan(ScanRequest(root: root, scope: .manualApply(identities)))
  }

  public func pause() async { await coordinator.pause() }
  public func resume() async { await coordinator.resume() }
  public func rulesDidChange() async { await coordinator.stabilityRulesDidChange() }
  public func shutdown() async { await coordinator.pause() }
}
