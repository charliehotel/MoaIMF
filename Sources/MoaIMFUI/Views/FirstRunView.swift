import AppKit
import SwiftUI

public struct FirstRunView: View {
  @ObservedObject private var controller: AppController
  @State private var selectedURL: URL?

  public init(controller: AppController) {
    self.controller = controller
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Label(MoaIMFLocalization.text("firstRun.title"), systemImage: "folder.badge.plus")
        .font(.title2.weight(.semibold))
      Text(MoaIMFLocalization.text("firstRun.body"))
        .foregroundStyle(.secondary)

      if let preview = controller.preview {
        previewSummary(preview)
      } else {
        Button(MoaIMFLocalization.text("firstRun.chooseDownloads")) { chooseFolder() }
          .keyboardShortcut(.defaultAction)
      }

      if let alert = controller.alert {
        Text(MoaIMFLocalization.text(alert.localizationKey))
          .foregroundStyle(.red)
          .accessibilityLabel(MoaIMFLocalization.text(alert.localizationKey))
      }
    }
    .frame(width: 420)
    .padding(24)
  }

  @ViewBuilder
  private func previewSummary(_ preview: PreviewState) -> some View {
    GroupBox {
      VStack(alignment: .leading, spacing: 8) {
        Text(preview.root.path)
          .font(.callout)
          .lineLimit(2)
          .textSelection(.enabled)
        LabeledContent(MoaIMFLocalization.text("folder.scan.total"), value: "\(preview.totalCount)")
        LabeledContent(MoaIMFLocalization.text("folder.scan.nfc"), value: "\(preview.nfcCount)")
        LabeledContent(MoaIMFLocalization.text("folder.scan.nfd"), value: "\(preview.nonNFCCount)")
        LabeledContent(
          MoaIMFLocalization.text("folder.scan.actionable"),
          value: "\(preview.actionableNonNFCCount)"
        )
        LabeledContent(
          MoaIMFLocalization.text("status.attention"), value: "\(preview.collisionCount)")
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }

    HStack {
      Button(MoaIMFLocalization.text("firstRun.watchNewOnly")) {
        guard let selectedURL else { return }
        Task { await controller.watchNewItemsOnly(in: selectedURL) }
      }
      Spacer()
      Button(MoaIMFLocalization.text("firstRun.normalizeExisting")) {
        Task { await controller.applyPreview() }
      }
      .keyboardShortcut(.defaultAction)
      .disabled(controller.isScanning)
    }
  }

  private func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = false
    panel.canCreateDirectories = false
    panel.prompt = MoaIMFLocalization.text("firstRun.chooseDownloads")
    panel.directoryURL =
      FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
    guard panel.runModal() == .OK, let url = panel.url else { return }
    selectedURL = url
    Task { await controller.previewExisting(in: url) }
  }
}
