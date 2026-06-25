import Combine
import Foundation

@MainActor
public final class MenuBarIconAnimator: ObservableObject {
  public static let frameInterval: TimeInterval = 1.5
  public static let frameCount = 4
  public static let pausedFrameIndex = 0

  @Published public private(set) var currentFrameIndex = 0
  private var animationTimer: Timer?
  private let animationTimerOwner = AnimationTimerOwner()
  private var isPaused = false

  var isAnimating: Bool { animationTimer != nil }

  public init(automaticallyStarts: Bool = true) {
    if automaticallyStarts { startAnimation() }
  }

  public func startAnimation() {
    guard !isPaused, animationTimer == nil else { return }
    let timer = Timer(timeInterval: Self.frameInterval, repeats: true) { [weak self] _ in
      Task { @MainActor [weak self] in self?.advanceFrame() }
    }
    RunLoop.main.add(timer, forMode: .common)
    animationTimerOwner.timer = timer
    animationTimer = timer
  }

  public func stopAnimation() {
    animationTimer?.invalidate()
    animationTimerOwner.timer = nil
    animationTimer = nil
  }

  public func setPaused(_ paused: Bool) {
    isPaused = paused
    if paused {
      stopAnimation()
      currentFrameIndex = Self.pausedFrameIndex
    } else {
      startAnimation()
    }
  }

  func advanceFrame() {
    guard !isPaused else { return }
    currentFrameIndex = (currentFrameIndex + 1) % Self.frameCount
  }
}

private final class AnimationTimerOwner {
  var timer: Timer? {
    didSet { oldValue?.invalidate() }
  }

  deinit {
    timer?.invalidate()
  }
}
