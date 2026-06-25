import AppKit
import MoaIMFCore
import SwiftUI
import XCTest

@testable import MoaIMFUI

final class VisualRenderingTests: XCTestCase {
  @MainActor
  func testFirstRunSettingsRendersToPNG() throws {
    let controller = MoaIMFEnvironment.makeController {}
    try render(
      SettingsView(controller: controller),
      named: "moaimf-settings-first-run.png",
      size: NSSize(width: 720, height: 520)
    )
  }

  @MainActor
  func testConfiguredSurfacesRenderToPNG() async throws {
    let data = SnapshotDataService()
    let scanController = SnapshotScanController()
    let controller = AppController(
      dataService: data,
      scanController: scanController,
      preferences: SnapshotPreferences(),
      terminate: {}
    )
    await controller.load()
    await controller.scanFolder(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)

    try render(
      SettingsView(controller: controller),
      named: "moaimf-settings-folders.png",
      size: NSSize(width: 800, height: 620)
    )
    try render(
      StabilityRulesView(controller: controller),
      named: "moaimf-settings-rules.png",
      size: NSSize(width: 700, height: 480)
    )
    try render(
      HistoryView(controller: controller),
      named: "moaimf-history.png",
      size: NSSize(width: 720, height: 480)
    )
    try render(
      HistoryView(controller: controller),
      named: "moaimf-history-minimum.png",
      size: HistoryView.minimumSize
    )
    try render(
      HistoryView(controller: controller, searchText: "한글"),
      named: "moaimf-history-search.png",
      size: NSSize(width: 720, height: 480)
    )
    try render(
      AboutView(
        info: AboutAppInfo(
          appName: "MoaIMF",
          version: "0.1.0",
          build: "1",
          copyright: "Copyright © 2026 copylawbot"
        )
      ),
      named: "moaimf-about.png",
      size: NSSize(width: 460, height: 320)
    )
    try render(
      LaunchHintView(),
      named: "moaimf-launch-hint.png",
      size: LaunchHintView.preferredSize
    )
    let report = try XCTUnwrap(
      controller.folderScanReports[UUID(uuidString: "00000000-0000-0000-0000-000000000001")!]
    )
    try render(
      FolderScanReportView(report: report).padding(20),
      named: "moaimf-folder-scan-report.png",
      size: NSSize(width: 720, height: 180)
    )
    try render(
      VStack(alignment: .leading, spacing: 8) {
        LoginItemStatusView(state: .enabled)
        LoginItemStatusView(state: .disabled)
        LoginItemStatusView(state: .requiresApproval)
        LoginItemStatusView(state: .notFound)
      }
      .padding(20),
      named: "moaimf-login-item-status.png",
      size: NSSize(width: 420, height: 160)
    )
  }

  @MainActor
  private func render<Content: View>(_ view: Content, named name: String, size: NSSize) throws {
    let hostingView = NSHostingView(rootView: view)
    hostingView.appearance = NSAppearance(named: .aqua)
    hostingView.wantsLayer = true
    hostingView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
    hostingView.frame = NSRect(origin: .zero, size: size)
    hostingView.layoutSubtreeIfNeeded()
    let representation = try XCTUnwrap(
      hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
    hostingView.cacheDisplay(in: hostingView.bounds, to: representation)
    let png = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
    let output = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    try png.write(to: output, options: .atomic)

    XCTAssertGreaterThan(png.count, 1_000)
  }
}

@MainActor
private final class SnapshotDataService: AppDataServicing {
  private let root = URL(
    fileURLWithPath: "/Users/example/Downloads/아주 긴 한국어 프로젝트 폴더/최종 산출물",
    isDirectory: true
  )

  func loadFolders() async throws -> [AppFolder] {
    [
      AppFolder(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        url: root,
        displayName: "최종 산출물",
        isEnabled: true,
        status: .available,
        lastScan: Date(),
        collisionCount: 0
      ),
      AppFolder(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID(),
        url: URL(fileURLWithPath: "/Volumes/외장 디스크/공유 자료"),
        displayName: "공유 자료",
        isEnabled: true,
        status: .disconnected,
        collisionCount: 2
      ),
    ]
  }

  func loadRules() async throws -> [StabilityExclusionRule] {
    StabilityExclusionMatcher.builtInRules + [
      StabilityExclusionRule(
        id: "snapshot.user",
        kind: .glob,
        pattern: "*.download-진행중-아주긴패턴-*",
        source: .user
      )
    ]
  }

  func loadHistory() async throws -> [HistoryEvent] {
    [
      HistoryEvent(
        timestamp: Date(),
        kind: .renamed,
        rootIdentifier: root.path,
        previousURL: root.appendingPathComponent("한글.txt"),
        resultingURL: root.appendingPathComponent("한글.txt"),
        reason: "renamed"
      ),
      HistoryEvent(
        timestamp: Date().addingTimeInterval(-60),
        kind: .collision,
        rootIdentifier: root.path,
        previousURL: root,
        resultingURL: nil,
        reason: "한글.txt 이름 충돌"
      ),
    ]
  }

  func addFolder(
    url: URL,
    mode: WatchedFolderNormalizationMode
  ) async throws -> AppFolder { try await loadFolders()[0] }
  func removeFolder(id: UUID) async throws {}
  func setFolderEnabled(id: UUID, enabled: Bool) async throws {}
  func reselectFolder(id: UUID, url: URL) async throws {}
  func addRule(kind: StabilityRuleKind, pattern: String) async throws -> StabilityExclusionRule {
    StabilityExclusionRule(id: "new", kind: kind, pattern: pattern, source: .user)
  }
  func removeRule(id: String) async throws {}
  func shutdown() async {}
}

@MainActor
private final class SnapshotScanController: AppScanControlling {
  func start(roots: [URL: Set<FileIdentity>]) async {}
  func updateRoots(_ roots: [URL: Set<FileIdentity>]) async {}
  func preview(root: URL) async throws -> ScanServiceResult {
    ScanServiceResult(
      summary: ScanContentSummary(totalEntryCount: 12, nfcEntryCount: 9, nonNFCEntryCount: 3),
      plan: NormalizationPlan(
        candidates: [
          RenameCandidate(
            identity: FileIdentity(volume: "snapshot", resource: "1"),
            source: root.appendingPathComponent("한글-보고서.txt"),
            targetName: "한글-보고서.txt"
          ),
          RenameCandidate(
            identity: FileIdentity(volume: "snapshot", resource: "2"),
            source: root.appendingPathComponent("사진.zip"),
            targetName: "사진.zip"
          ),
        ],
        collisions: []
      ),
      deferredIdentities: [FileIdentity(volume: "snapshot", resource: "partial")]
    )
  }
  func apply(root: URL, identities: Set<FileIdentity>) async throws -> ScanServiceResult {
    ScanServiceResult()
  }
  func pause() async {}
  func resume() async {}
  func rulesDidChange() async {}
  func shutdown() async {}
}

@MainActor
private final class SnapshotPreferences: AppPreferencesStoring {
  var isPaused = false
  var language: MoaIMFLanguage = .system
  var isLaunchHintHidden = false
}
