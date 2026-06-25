import XCTest

@testable import MoaIMFUI

@MainActor
final class MenuBarIconAnimatorTests: XCTestCase {
  func testStartsWithInitialAndCyclesThroughMedialFinalAndCompletedFrames() {
    let animator = MenuBarIconAnimator(automaticallyStarts: false)

    XCTAssertEqual(MenuBarIconAnimator.frameInterval, 1.5)
    XCTAssertEqual(animator.currentFrameIndex, 0)

    animator.advanceFrame()
    XCTAssertEqual(animator.currentFrameIndex, 1)
    animator.advanceFrame()
    XCTAssertEqual(animator.currentFrameIndex, 2)
    animator.advanceFrame()
    XCTAssertEqual(animator.currentFrameIndex, 3)
    animator.advanceFrame()
    XCTAssertEqual(animator.currentFrameIndex, 0)
  }

  func testPauseStopsAnimationAndShowsInitialFrame() {
    let animator = MenuBarIconAnimator(automaticallyStarts: false)

    animator.advanceFrame()
    animator.advanceFrame()
    XCTAssertEqual(animator.currentFrameIndex, 2)

    animator.startAnimation()
    XCTAssertTrue(animator.isAnimating)

    animator.setPaused(true)
    XCTAssertFalse(animator.isAnimating)
    XCTAssertEqual(animator.currentFrameIndex, MenuBarIconAnimator.pausedFrameIndex)
  }

  func testPausedAnimatorDoesNotRestartOrAdvance() {
    let animator = MenuBarIconAnimator(automaticallyStarts: false)

    animator.setPaused(true)
    animator.startAnimation()
    animator.advanceFrame()

    XCTAssertFalse(animator.isAnimating)
    XCTAssertEqual(animator.currentFrameIndex, MenuBarIconAnimator.pausedFrameIndex)

    animator.setPaused(false)
    XCTAssertTrue(animator.isAnimating)
    animator.stopAnimation()
  }
}
