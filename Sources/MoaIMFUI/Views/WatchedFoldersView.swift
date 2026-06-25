import AppKit
import MoaIMFCore
import SwiftUI

struct WatchedFoldersView: View {
  @ObservedObject var controller: AppController
  @State private var selection: UUID?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      statusHeader
      List(controller.folders, selection: $selection) { folder in
        folderRow(folder)
          .tag(folder.id)
      }
      .frame(minHeight: 280)

      HStack(spacing: 0) {
        Button(action: addFolder) { Image(systemName: "plus") }
          .accessibilityLabel(MoaIMFLocalization.text("folder.add"))
        Button(role: .destructive, action: removeSelected) { Image(systemName: "minus") }
          .accessibilityLabel(MoaIMFLocalization.text("folder.remove"))
          .disabled(selection == nil)
      }
      .buttonStyle(.borderless)

      Text(MoaIMFLocalization.text("folder.removeExplanation"))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  private var statusHeader: some View {
    Label(
      MoaIMFLocalization.text(controller.status.localizationKey),
      systemImage: controller.status.symbolName
    )
    .font(.headline)
  }

  private func folderRow(_ folder: AppFolder) -> some View {
    HStack(spacing: 12) {
      Image(systemName: symbol(for: folder.status))
        .frame(width: 20)
      VStack(alignment: .leading, spacing: 3) {
        Text(folder.displayName).font(.body.weight(.medium))
        Text(folder.url.path)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        Text(statusText(folder))
          .font(.caption)
          .foregroundStyle(.secondary)
        if let report = controller.folderScanReports[folder.id] {
          FolderScanReportView(report: report)
        }
      }
      Spacer()
      Toggle(
        "",
        isOn: Binding(
          get: { folder.isEnabled },
          set: { value in Task { await controller.setFolderEnabled(id: folder.id, enabled: value) }
          }
        )
      )
      .labelsHidden()
      .accessibilityLabel(folder.displayName)
      Button(MoaIMFLocalization.text("folder.scan")) {
        Task { await controller.scanFolder(id: folder.id) }
      }
      .disabled(controller.isScanning || folder.status != .available)
      Button(MoaIMFLocalization.text("folder.reselect")) { reselect(folder) }
    }
    .padding(.vertical, 4)
  }

  private func statusText(_ folder: AppFolder) -> String {
    switch folder.status {
    case .available:
      if let date = folder.lastScan {
        return date.formatted(date: .abbreviated, time: .shortened)
      }
      return MoaIMFLocalization.text("status.watching")
    case .permissionRequired: return MoaIMFLocalization.text("status.permissionRequired")
    case .disconnected: return MoaIMFLocalization.text("status.disconnected")
    }
  }

  private func symbol(for status: WatchedFolderStatus) -> String {
    switch status {
    case .available: "folder"
    case .permissionRequired: "lock.trianglebadge.exclamationmark"
    case .disconnected: "externaldrive.badge.exclamationmark"
    }
  }

  private func addFolder() {
    guard let url = chooseFolder(startingAt: nil) else { return }
    Task { await controller.watchNewItemsOnly(in: url) }
  }

  private func reselect(_ folder: AppFolder) {
    guard let url = chooseFolder(startingAt: folder.url) else { return }
    Task { await controller.reselectFolder(id: folder.id, url: url) }
  }

  private func removeSelected() {
    guard let selection else { return }
    Task {
      await controller.removeFolder(id: selection)
      self.selection = nil
    }
  }

  private func chooseFolder(startingAt url: URL?) -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.directoryURL = url
    return panel.runModal() == .OK ? panel.url : nil
  }
}

struct FolderScanReportView: View {
  let report: FolderScanReport

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(scanSummaryText)
        .font(.caption)
        .foregroundStyle(.secondary)
      if report.actionableNonNFCCount == 0 && report.collisionCount == 0 {
        Label(MoaIMFLocalization.text("folder.scan.clean"), systemImage: "checkmark.circle")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        ForEach(report.candidateSamples, id: \.identity) { candidate in
          Label(candidate.source.lastPathComponent, systemImage: "text.badge.checkmark")
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        if report.actionableNonNFCCount > report.candidateSamples.count {
          Text(
            String(
              format: MoaIMFLocalization.text("folder.scan.more"),
              report.actionableNonNFCCount - report.candidateSamples.count
            )
          )
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      }
    }
  }

  private var scanSummaryText: String {
    String(
      format: MoaIMFLocalization.text("folder.scan.summary"),
      report.totalCount,
      report.nfcCount,
      report.nonNFCCount,
      report.actionableNonNFCCount,
      report.collisionCount,
      report.deferredCount,
      report.scannedAt.formatted(date: .omitted, time: .shortened)
    )
  }
}
