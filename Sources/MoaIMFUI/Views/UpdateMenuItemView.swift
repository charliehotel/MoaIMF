import AppKit
import SwiftUI

struct UpdateMenuItemRepresentable: NSViewRepresentable {
  let update: AppUpdate
  let onCheck: @MainActor () -> Void
  let onDownload: @MainActor () -> Void

  func makeNSView(context: Context) -> UpdateMenuItemView {
    UpdateMenuItemView(
      update: update,
      onCheck: onCheck,
      onDownload: onDownload
    )
  }

  func updateNSView(_ nsView: UpdateMenuItemView, context: Context) {
    nsView.configure(
      update: update,
      onCheck: onCheck,
      onDownload: onDownload
    )
  }
}

@MainActor
final class UpdateMenuItemView: NSView {
  static let rowHeight: CGFloat = 26
  static let menuRowLeadingInset: CGFloat = {
    let item = NSMenuItem(title: " ", action: nil, keyEquivalent: "")
    let cell = NSMenuItemCell()
    cell.menuItem = item
    cell.calcSize()
    let titleMinX = cell.titleRect(
      forBounds: NSRect(x: 0, y: 0, width: 220, height: rowHeight)
    ).minX
    let referenceLabel = NSTextField(labelWithString: " ")
    referenceLabel.font = NSFont.menuFont(ofSize: 0)
    return titleMinX - referenceLabel.alignmentRectInsets.left
  }()
  private static let nativeMenuTrailingInset: CGFloat = 8
  private static let downloadButtonWidth: CGFloat = 24
  private static let buttonGap: CGFloat = 6

  private let checkButton = NSButton(title: "", target: nil, action: nil)
  private let downloadButton = NSButton(image: NSImage(), target: nil, action: nil)
  private var onCheck: @MainActor () -> Void
  private var onDownload: @MainActor () -> Void

  init(
    update: AppUpdate,
    onCheck: @escaping @MainActor () -> Void,
    onDownload: @escaping @MainActor () -> Void
  ) {
    self.onCheck = onCheck
    self.onDownload = onDownload
    super.init(frame: .zero)
    autoresizingMask = [.width]
    configureButtons()
    configure(update: update, onCheck: onCheck, onDownload: onDownload)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var intrinsicContentSize: NSSize {
    let titleWidth = checkButton.attributedTitle.size().width
    return NSSize(
      width: titleWidth
        + Self.menuRowLeadingInset
        + Self.buttonGap
        + Self.downloadButtonWidth
        + Self.nativeMenuTrailingInset,
      height: Self.rowHeight
    )
  }

  override func layout() {
    super.layout()

    let buttonHeight = min(Self.rowHeight, bounds.height)
    let buttonY = max(0, (bounds.height - buttonHeight) / 2)

    checkButton.frame = NSRect(
      x: Self.menuRowLeadingInset,
      y: buttonY,
      width: max(
        0,
        bounds.width
          - Self.menuRowLeadingInset
          - Self.buttonGap
          - Self.downloadButtonWidth
          - Self.nativeMenuTrailingInset
      ),
      height: buttonHeight
    )
    downloadButton.frame = NSRect(
      x: max(
        Self.menuRowLeadingInset,
        bounds.width - Self.nativeMenuTrailingInset - Self.downloadButtonWidth
      ),
      y: buttonY,
      width: Self.downloadButtonWidth,
      height: buttonHeight
    )
  }

  override func mouseDown(with event: NSEvent) {
    let location = convert(event.locationInWindow, from: nil)
    if downloadButton.frame.contains(location) {
      onDownload()
    } else {
      onCheck()
    }
  }

  func configure(
    update: AppUpdate,
    onCheck: @escaping @MainActor () -> Void,
    onDownload: @escaping @MainActor () -> Void
  ) {
    self.onCheck = onCheck
    self.onDownload = onDownload

    checkButton.title = MoaIMFLocalization.text("menu.checkForUpdates")
    checkButton.toolTip = checkButton.title
    checkButton.setAccessibilityLabel(checkButton.title)

    let downloadTitle = String(
      format: MoaIMFLocalization.text("menu.downloadUpdate"),
      update.version
    )
    downloadButton.toolTip = downloadTitle
    downloadButton.setAccessibilityLabel(downloadTitle)

    invalidateIntrinsicContentSize()
    needsLayout = true
  }

  private func configureButtons() {
    checkButton.identifier = NSUserInterfaceItemIdentifier("MoaIMF.update.check")
    downloadButton.identifier = NSUserInterfaceItemIdentifier("MoaIMF.update.download")

    for button in [checkButton, downloadButton] {
      button.translatesAutoresizingMaskIntoConstraints = true
      button.isBordered = false
      button.bezelStyle = .inline
      button.font = NSFont.menuFont(ofSize: 0)
      button.focusRingType = .none
      button.alignment = .left
      button.target = self
    }

    checkButton.action = #selector(checkButtonClicked)
    downloadButton.action = #selector(downloadButtonClicked)
    downloadButton.image = NSImage(
      systemSymbolName: "arrow.down.circle",
      accessibilityDescription: nil
    )
    downloadButton.imagePosition = .imageOnly
    downloadButton.imageScaling = .scaleProportionallyDown
    downloadButton.contentTintColor = .controlTextColor

    addSubview(checkButton)
    addSubview(downloadButton)
    setAccessibilityElement(false)
  }

  @objc private func checkButtonClicked() {
    onCheck()
  }

  @objc private func downloadButtonClicked() {
    onDownload()
  }
}
