import AppKit
import MoaIMFUI
import SwiftUI

struct MenuBarIconLabel: View {
  @ObservedObject var controller: AppController
  @StateObject private var animator = MenuBarIconAnimator()

  var body: some View {
    icon(frame: animator.currentFrameIndex)
      .onAppear {
        animator.setPaused(controller.status == .paused)
      }
      .onChange(of: controller.status) { newStatus in
        animator.setPaused(newStatus == .paused)
      }
  }

  @ViewBuilder
  private func icon(frame: Int) -> some View {
    if let image = MenuBarIconAssets.frames[frame] {
      Image(nsImage: image)
    } else {
      Image(systemName: controller.status.symbolName)
    }
  }
}

@MainActor
private enum MenuBarIconAssets {
  static let frames: [NSImage?] = (0...3).map { loadFrame($0) }
  private static let logicalSize = NSSize(width: 18, height: 18)

  private static func loadFrame(_ frame: Int) -> NSImage? {
    let image = NSImage(size: logicalSize)
    for suffix in ["", "@2x"] {
      guard
        let url = Bundle.main.url(
          forResource: "han_frame_\(frame)\(suffix)",
          withExtension: "png",
          subdirectory: "Assets.xcassets"
        ),
        let source = NSImage(contentsOf: url)
      else { continue }
      for representation in source.representations {
        representation.size = logicalSize
        image.addRepresentation(representation)
      }
    }
    guard !image.representations.isEmpty else { return nil }
    image.isTemplate = true
    return image
  }
}
