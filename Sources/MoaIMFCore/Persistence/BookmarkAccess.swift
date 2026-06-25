import Foundation

public protocol BookmarkCoding: Sendable {
  func create(for url: URL) throws -> Data
  func resolve(_ data: Data) throws -> ResolvedBookmark
}

public struct ResolvedBookmark: Sendable {
  public let url: URL
  public let isStale: Bool

  public init(url: URL, isStale: Bool) {
    self.url = url
    self.isStale = isStale
  }
}

public protocol ScopedResourceAccessing: Sendable {
  func start(_ url: URL) -> Bool
  func stop(_ url: URL)
}

public struct FoundationBookmarkCoder: BookmarkCoding {
  public init() {}

  public func create(for url: URL) throws -> Data {
    try url.bookmarkData(
      options: [.withSecurityScope],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
  }

  public func resolve(_ data: Data) throws -> ResolvedBookmark {
    var isStale = false
    let url = try URL(
      resolvingBookmarkData: data,
      options: [.withSecurityScope],
      relativeTo: nil,
      bookmarkDataIsStale: &isStale
    )
    return ResolvedBookmark(url: url, isStale: isStale)
  }
}

public struct FoundationScopedResourceAccessor: ScopedResourceAccessing {
  public init() {}

  public func start(_ url: URL) -> Bool {
    url.startAccessingSecurityScopedResource()
  }

  public func stop(_ url: URL) {
    url.stopAccessingSecurityScopedResource()
  }
}
