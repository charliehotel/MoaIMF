import Foundation
import XCTest

@testable import MoaIMFCore

struct LegacyPayload: Codable {
  let version: Int
  let folders: [LegacyFolder]
}

struct LegacyFolder: Codable {
  let id: UUID
  let bookmarkData: Data
  let displayName: String
  let isEnabled: Bool
  let lastStableIdentity: FileIdentity?
  let status: WatchedFolderStatus
}

final class WatchedFolderFixture {
  let persistenceRoot: URL
  let root: URL
  let codec = FakeBookmarkCodec()
  let accessor = FakeScopedResourceAccessor()

  init() throws {
    persistenceRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    root = persistenceRoot.appendingPathComponent("watched", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
  }

  func makeStore(fileName: String = "watched-folders.json") -> WatchedFolderStore {
    WatchedFolderStore(
      fileURL: persistenceRoot.appendingPathComponent(fileName),
      bookmarkCoder: codec,
      resourceAccessor: accessor
    )
  }

  func remove() {
    try? FileManager.default.removeItem(at: persistenceRoot)
  }
}

final class FakeBookmarkCodec: BookmarkCoding, @unchecked Sendable {
  private let lock = NSLock()
  private var generation = 0
  private var staleData: Set<Data> = []

  func create(for url: URL) throws -> Data {
    lock.withLock {
      generation += 1
      return Data("\(generation)|\(url.path)".utf8)
    }
  }

  func resolve(_ data: Data) throws -> ResolvedBookmark {
    try lock.withLock {
      guard
        let value = String(data: data, encoding: .utf8),
        let separator = value.firstIndex(of: "|")
      else {
        throw WatchedFolderError.invalidBookmark
      }
      let path = String(value[value.index(after: separator)...])
      return ResolvedBookmark(
        url: URL(fileURLWithPath: path, isDirectory: true),
        isStale: staleData.contains(data)
      )
    }
  }

  func markStale(_ data: Data) {
    lock.withLock { _ = staleData.insert(data) }
  }
}

final class FakeScopedResourceAccessor: ScopedResourceAccessing, @unchecked Sendable {
  private let lock = NSLock()
  private var storedAllowsAccess = true
  private var storedStartCount = 0
  private var storedStopCount = 0

  var allowsAccess: Bool {
    get { lock.withLock { storedAllowsAccess } }
    set { lock.withLock { storedAllowsAccess = newValue } }
  }
  var startCount: Int { lock.withLock { storedStartCount } }
  var stopCount: Int { lock.withLock { storedStopCount } }

  func start(_ url: URL) -> Bool {
    lock.withLock {
      storedStartCount += 1
      return storedAllowsAccess
    }
  }

  func stop(_ url: URL) {
    lock.withLock { storedStopCount += 1 }
  }
}

func assertFolderError<T>(
  _ expected: WatchedFolderError,
  operation: () async throws -> T
) async {
  do {
    _ = try await operation()
    XCTFail("Expected \(expected)")
  } catch {
    XCTAssertEqual(error as? WatchedFolderError, expected)
  }
}
