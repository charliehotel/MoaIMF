import Foundation
import XCTest

@testable import MoaIMFCore

final class WatchedFolderStoreTests: XCTestCase {
  func testAddsRemovesAndTogglesFolder() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let store = fixture.makeStore()

    let added = try await store.add(url: fixture.root)
    try await store.setEnabled(id: added.id, enabled: false)
    let disabledFolders = try await store.folders()
    let disabled = try XCTUnwrap(disabledFolders.first)
    try await store.setEnabled(id: added.id, enabled: true)
    let enabledFolders = try await store.folders()
    let enabled = try XCTUnwrap(enabledFolders.first)
    try await store.remove(id: added.id)
    let remaining = try await store.folders()

    XCTAssertFalse(disabled.isEnabled)
    XCTAssertTrue(enabled.isEnabled)
    XCTAssertTrue(remaining.isEmpty)
  }

  func testPersistsAcrossStoreRestart() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let firstStore = fixture.makeStore()
    let added = try await firstStore.add(url: fixture.root)
    let secondStore = fixture.makeStore()

    let reloaded = try await secondStore.folders()

    XCTAssertEqual(reloaded.map(\.id), [added.id])
    XCTAssertEqual(reloaded.first?.lastStableIdentity, added.lastStableIdentity)
  }

  func testNewItemsOnlyPersistsExistingIdentityBaseline() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let existing = fixture.root.appendingPathComponent("existing.txt")
    try Data("existing".utf8).write(to: existing)
    let firstStore = fixture.makeStore()

    let added = try await firstStore.add(url: fixture.root, mode: .newItemsOnly)
    let reloaded = try await fixture.makeStore().folders()

    XCTAssertEqual(added.normalizationMode, .newItemsOnly)
    XCTAssertEqual(added.excludedExistingIdentities.count, 1)
    XCTAssertEqual(reloaded.first?.excludedExistingIdentities, added.excludedExistingIdentities)
  }

  func testRejectsDuplicateAndParentChildOverlapBothDirections() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let child = fixture.root.appendingPathComponent("child", isDirectory: true)
    try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
    let duplicateStore = fixture.makeStore(fileName: "duplicate.json")
    _ = try await duplicateStore.add(url: fixture.root)
    await assertFolderError(.duplicateRoot) { try await duplicateStore.add(url: fixture.root) }
    await assertFolderError(.overlappingRoot) { try await duplicateStore.add(url: child) }

    let childFirstStore = fixture.makeStore(fileName: "child-first.json")
    _ = try await childFirstStore.add(url: child)
    await assertFolderError(.overlappingRoot) { try await childFirstStore.add(url: fixture.root) }
  }

  func testRefreshesStaleBookmarkData() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let store = fixture.makeStore()
    let added = try await store.add(url: fixture.root)
    fixture.codec.markStale(added.bookmarkData)
    let refreshedFolders = try await store.folders()

    let refreshed = try XCTUnwrap(refreshedFolders.first)

    XCTAssertNotEqual(refreshed.bookmarkData, added.bookmarkData)
    XCTAssertEqual(refreshed.status, .available)
  }

  func testMarksDisconnectedFolderWithoutDroppingRecord() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let store = fixture.makeStore()
    let added = try await store.add(url: fixture.root)
    try FileManager.default.removeItem(at: fixture.root)
    let disconnectedFolders = try await store.folders()

    let disconnected = try XCTUnwrap(disconnectedFolders.first)

    XCTAssertEqual(disconnected.id, added.id)
    XCTAssertEqual(disconnected.status, .disconnected)
  }

  func testReportsPermissionRequiredAndBalancesSuccessfulAccess() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let store = fixture.makeStore()
    let added = try await store.add(url: fixture.root)
    let value = try await store.withAccess(id: added.id) { url in url.lastPathComponent }

    XCTAssertEqual(value, fixture.root.lastPathComponent)
    XCTAssertEqual(fixture.accessor.startCount, 2)
    XCTAssertEqual(fixture.accessor.stopCount, 2)

    fixture.accessor.allowsAccess = false
    let deniedFolders = try await store.folders()
    let denied = try XCTUnwrap(deniedFolders.first)
    XCTAssertEqual(denied.status, .permissionRequired)
  }

  func testActiveAccessPersistsUntilFolderIsDisabled() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let store = fixture.makeStore()
    let added = try await store.add(url: fixture.root)

    let active = try await store.activateEnabledFolders()
    let startCountAfterActivation = fixture.accessor.startCount
    _ = try await store.activateEnabledFolders()

    XCTAssertEqual(active[added.id]?.lastPathComponent, fixture.root.lastPathComponent)
    XCTAssertEqual(fixture.accessor.startCount, startCountAfterActivation)

    try await store.setEnabled(id: added.id, enabled: false)

    XCTAssertEqual(fixture.accessor.stopCount, 2)
  }

  func testReselectReplacesBookmarkWithoutChangingIdentity() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let replacement = fixture.persistenceRoot.appendingPathComponent(
      "replacement", isDirectory: true)
    try FileManager.default.createDirectory(at: replacement, withIntermediateDirectories: true)
    let store = fixture.makeStore()
    let added = try await store.add(url: fixture.root)

    let updated = try await store.reselect(id: added.id, url: replacement)
    let resolved = try await store.resolvedURL(id: added.id)

    XCTAssertEqual(updated.id, added.id)
    XCTAssertEqual(updated.displayName, "replacement")
    XCTAssertEqual(resolved.lastPathComponent, "replacement")
  }

  func testReselectRefreshesNewItemsOnlyBaselineForReplacementFolder() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let replacement = fixture.persistenceRoot.appendingPathComponent(
      "replacement-new-only", isDirectory: true)
    try FileManager.default.createDirectory(at: replacement, withIntermediateDirectories: true)
    try Data("replacement".utf8).write(
      to: replacement.appendingPathComponent("existing.txt"))
    let store = fixture.makeStore()
    let added = try await store.add(url: fixture.root, mode: .newItemsOnly)

    let updated = try await store.reselect(id: added.id, url: replacement)

    XCTAssertEqual(updated.normalizationMode, .newItemsOnly)
    XCTAssertEqual(updated.excludedExistingIdentities.count, 1)
  }

  func testZeroRootStateIsValid() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }

    let folders = try await fixture.makeStore().folders()

    XCTAssertTrue(folders.isEmpty)
  }

  func testUnsupportedSchemaDoesNotOverwriteReadableFile() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let fileURL = fixture.persistenceRoot.appendingPathComponent("future.json")
    let original = Data("{\"version\":2,\"folders\":[]}".utf8)
    try original.write(to: fileURL)
    let store = fixture.makeStore(fileName: "future.json")

    await assertFolderError(.unsupportedVersion) { try await store.add(url: fixture.root) }

    XCTAssertEqual(try Data(contentsOf: fileURL), original)
  }

  func testLegacyVersionOneRecordDefaultsToAllItemsMode() async throws {
    let fixture = try WatchedFolderFixture()
    defer { fixture.remove() }
    let fileURL = fixture.persistenceRoot.appendingPathComponent("legacy.json")
    let legacy = LegacyPayload(
      version: 1,
      folders: [
        LegacyFolder(
          id: UUID(),
          bookmarkData: try fixture.codec.create(for: fixture.root),
          displayName: fixture.root.lastPathComponent,
          isEnabled: true,
          lastStableIdentity: nil,
          status: .available
        )
      ]
    )
    try JSONEncoder().encode(legacy).write(to: fileURL)

    let folders = try await fixture.makeStore(fileName: "legacy.json").folders()

    XCTAssertEqual(folders.first?.normalizationMode, .allItems)
    XCTAssertEqual(folders.first?.excludedExistingIdentities, [])
  }
}
