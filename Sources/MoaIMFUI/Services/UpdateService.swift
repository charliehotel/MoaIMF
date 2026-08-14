import CryptoKit
import Foundation

public struct AppUpdate: Equatable, Identifiable, Sendable {
  public let version: String
  public let tagName: String
  public let releaseURL: URL
  public let assetName: String
  public let downloadURL: URL
  public let digest: String?
  public let releaseNotes: String

  public var id: String { tagName }

  public init(
    version: String,
    tagName: String,
    releaseURL: URL,
    assetName: String,
    downloadURL: URL,
    digest: String? = nil,
    releaseNotes: String = ""
  ) {
    self.version = version
    self.tagName = tagName
    self.releaseURL = releaseURL
    self.assetName = assetName
    self.downloadURL = downloadURL
    self.digest = digest
    self.releaseNotes = releaseNotes
  }
}

public enum AppUpdateCheckResult: Equatable, Sendable {
  case current(latestVersion: String)
  case available(AppUpdate)
}

public enum AppUpdateStatus: Equatable, Sendable {
  case idle
  case checking
  case current
  case available
  case downloading
  case downloaded
  case failed
}

public enum AppUpdateError: LocalizedError, Equatable, Sendable {
  case invalidResponse
  case httpStatus(Int)
  case invalidRelease
  case invalidVersion(String)
  case noDownloadAsset
  case checksumMismatch

  public var errorDescription: String? {
    switch self {
    case .invalidResponse:
      "The update server returned an invalid response."
    case .httpStatus(let statusCode):
      "The update server returned HTTP status \(statusCode)."
    case .invalidRelease:
      "The latest GitHub release could not be read."
    case .invalidVersion(let value):
      "The release version is not valid: \(value)"
    case .noDownloadAsset:
      "The latest release has no downloadable macOS asset."
    case .checksumMismatch:
      "The downloaded update failed its checksum verification."
    }
  }
}

@MainActor
public protocol AppUpdateServicing: AnyObject {
  func check(currentVersion: String) async throws -> AppUpdateCheckResult
  func download(_ update: AppUpdate) async throws -> URL
}

@MainActor
public protocol UpdateNetworkClient: AnyObject {
  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
  func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse)
}

@MainActor
public final class URLSessionUpdateNetworkClient: UpdateNetworkClient {
  private let session: URLSession

  public init(session: URLSession = .shared) {
    self.session = session
  }

  public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw AppUpdateError.invalidResponse
    }
    return (data, response)
  }

  public func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse) {
    let (url, response) = try await session.download(for: request)
    guard let response = response as? HTTPURLResponse else {
      throw AppUpdateError.invalidResponse
    }
    return (url, response)
  }
}

@MainActor
public final class NoopAppUpdateService: AppUpdateServicing {
  public init() {}

  public func check(currentVersion: String) async throws -> AppUpdateCheckResult {
    .current(latestVersion: currentVersion)
  }

  public func download(_ update: AppUpdate) async throws -> URL {
    throw AppUpdateError.noDownloadAsset
  }
}

@MainActor
public final class GitHubUpdateService: AppUpdateServicing {
  public static let defaultAPIURL = URL(
    string: "https://api.github.com/repos/charliehotel/MoaIMF/releases/latest"
  )!

  private let apiURL: URL
  private let networkClient: any UpdateNetworkClient
  private let fileManager: FileManager
  private let downloadsDirectory: URL
  private let decoder = JSONDecoder()

  public init(
    apiURL: URL = GitHubUpdateService.defaultAPIURL,
    networkClient: any UpdateNetworkClient = URLSessionUpdateNetworkClient(),
    fileManager: FileManager = .default,
    downloadsDirectory: URL? = nil
  ) {
    self.apiURL = apiURL
    self.networkClient = networkClient
    self.fileManager = fileManager
    self.downloadsDirectory =
      downloadsDirectory
      ?? fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
      ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
  }

  public func check(currentVersion: String) async throws -> AppUpdateCheckResult {
    guard let currentVersion = AppVersion(currentVersion) else {
      throw AppUpdateError.invalidVersion(currentVersion)
    }

    var request = URLRequest(url: apiURL)
    request.timeoutInterval = 15
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    request.setValue("MoaIMF/\(currentVersion)", forHTTPHeaderField: "User-Agent")

    let (data, response) = try await networkClient.data(for: request)
    guard (200..<300).contains(response.statusCode) else {
      throw AppUpdateError.httpStatus(response.statusCode)
    }

    let release: GitHubRelease
    do {
      release = try decoder.decode(GitHubRelease.self, from: data)
    } catch {
      throw AppUpdateError.invalidRelease
    }

    guard !release.draft, !release.prerelease, let releaseVersion = AppVersion(release.tagName)
    else {
      throw AppUpdateError.invalidRelease
    }

    guard releaseVersion > currentVersion else {
      return .current(latestVersion: releaseVersion.description)
    }

    guard
      let asset = release.assets
        .filter({ $0.state == "uploaded" && Self.isSupportedAsset($0.name) })
        .sorted(by: Self.assetPrecedes)
        .first,
      !URL(fileURLWithPath: asset.name).lastPathComponent.isEmpty
    else {
      throw AppUpdateError.noDownloadAsset
    }

    let assetName = URL(fileURLWithPath: asset.name).lastPathComponent

    return .available(
      AppUpdate(
        version: releaseVersion.description,
        tagName: release.tagName,
        releaseURL: release.htmlURL,
        assetName: assetName,
        downloadURL: asset.browserDownloadURL,
        digest: asset.digest,
        releaseNotes: Self.releaseNotes(from: release.body)
      )
    )
  }

  public func download(_ update: AppUpdate) async throws -> URL {
    var request = URLRequest(url: update.downloadURL)
    request.timeoutInterval = 60
    request.setValue("MoaIMF update downloader", forHTTPHeaderField: "User-Agent")

    let (temporaryURL, response) = try await networkClient.download(for: request)
    guard (200..<300).contains(response.statusCode) else {
      removeTemporaryFile(temporaryURL)
      throw AppUpdateError.httpStatus(response.statusCode)
    }
    defer { removeTemporaryFile(temporaryURL) }

    try verifyDigest(update.digest, fileURL: temporaryURL)
    try fileManager.createDirectory(
      at: downloadsDirectory,
      withIntermediateDirectories: true
    )

    let destination = uniqueDestination(for: update.assetName)
    try fileManager.moveItem(at: temporaryURL, to: destination)
    return destination
  }

  private static func assetPrecedes(_ lhs: GitHubAsset, _ rhs: GitHubAsset) -> Bool {
    let lhsRank = assetRank(lhs.name)
    let rhsRank = assetRank(rhs.name)
    return lhsRank == rhsRank
      ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : lhsRank < rhsRank
  }

  private static func assetRank(_ name: String) -> Int {
    let lowercased = name.lowercased()
    guard lowercased.hasPrefix("moaimf-") else { return 2 }
    if lowercased.hasSuffix(".dmg") { return 0 }
    if lowercased.hasSuffix(".zip") { return 1 }
    return 2
  }

  private static func isSupportedAsset(_ name: String) -> Bool {
    let lowercased = name.lowercased()
    return lowercased.hasPrefix("moaimf-")
      && (lowercased.hasSuffix(".dmg") || lowercased.hasSuffix(".zip"))
  }

  private static func releaseNotes(from body: String?) -> String {
    body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
  }

  private func uniqueDestination(for assetName: String) -> URL {
    let safeName = URL(fileURLWithPath: assetName).lastPathComponent
    let base = downloadsDirectory.appendingPathComponent(safeName)
    guard fileManager.fileExists(atPath: base.path) else { return base }

    let pathExtension = base.pathExtension
    let stem = base.deletingPathExtension().lastPathComponent
    var index = 2
    while true {
      let numberedName =
        pathExtension.isEmpty
        ? "\(stem) (\(index))"
        : "\(stem) (\(index)).\(pathExtension)"
      let candidate = downloadsDirectory.appendingPathComponent(numberedName)
      if !fileManager.fileExists(atPath: candidate.path) { return candidate }
      index += 1
    }
  }

  private func verifyDigest(_ digest: String?, fileURL: URL) throws {
    guard let digest, digest.lowercased().hasPrefix("sha256:") else { return }
    let expected = String(digest.dropFirst("sha256:".count)).lowercased()
    var hasher = SHA256()
    let handle = try FileHandle(forReadingFrom: fileURL)
    defer { try? handle.close() }

    while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
      hasher.update(data: chunk)
    }
    let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    guard actual == expected else { throw AppUpdateError.checksumMismatch }
  }

  private func removeTemporaryFile(_ url: URL) {
    guard fileManager.fileExists(atPath: url.path) else { return }
    try? fileManager.removeItem(at: url)
  }
}

struct AppVersion: Comparable, CustomStringConvertible, Sendable {
  private let components: [Int]

  init?(_ rawValue: String) {
    guard
      let range = rawValue.range(
        of: #"\d+(?:\.\d+){1,2}"#,
        options: .regularExpression
      )
    else { return nil }

    let values = rawValue[range].split(separator: ".").compactMap { Int($0) }
    guard values.count >= 2, values.count <= 3 else { return nil }
    components = values + Array(repeating: 0, count: 3 - values.count)
  }

  var description: String { components.map(String.init).joined(separator: ".") }

  static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
    zip(lhs.components, rhs.components).first { $0 != $1 }.map { $0.0 < $0.1 } ?? false
  }
}

private struct GitHubRelease: Decodable {
  let tagName: String
  let htmlURL: URL
  let draft: Bool
  let prerelease: Bool
  let assets: [GitHubAsset]
  let body: String?

  enum CodingKeys: String, CodingKey {
    case tagName = "tag_name"
    case htmlURL = "html_url"
    case draft
    case prerelease
    case assets
    case body
  }
}

private struct GitHubAsset: Decodable {
  let name: String
  let browserDownloadURL: URL
  let state: String
  let digest: String?

  enum CodingKeys: String, CodingKey {
    case name
    case browserDownloadURL = "browser_download_url"
    case state
    case digest
  }
}
