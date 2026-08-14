import Foundation
import XCTest

@testable import MoaIMFUI

@MainActor
final class UpdateServiceTests: XCTestCase {
  func testFindsNewDMGFromLatestGitHubRelease() async throws {
    let client = FakeUpdateNetworkClient(
      data: Data(
        """
        {
          "tag_name": "v0.1.2",
          "html_url": "https://github.com/charliehotel/MoaIMF/releases/tag/v0.1.2",
          "draft": false,
          "prerelease": false,
          "body": "# MoaIMF 0.1.2\\n\\n- Improves update checks.\\n- Clarifies the download flow.\\n- Keeps the download button visible.\\n- Shows the full release notes.",
          "assets": [
            {
              "name": "MoaIMF-0.1.2.zip",
              "browser_download_url": "https://github.com/charliehotel/MoaIMF/releases/download/v0.1.2/MoaIMF-0.1.2.zip",
              "state": "uploaded",
              "digest": null
            },
            {
              "name": "MoaIMF-0.1.2.dmg",
              "browser_download_url": "https://github.com/charliehotel/MoaIMF/releases/download/v0.1.2/MoaIMF-0.1.2.dmg",
              "state": "uploaded",
              "digest": "sha256:abc"
            }
          ]
        }
        """.utf8
      )
    )
    let service = GitHubUpdateService(
      apiURL: URL(string: "https://example.com/releases/latest")!,
      networkClient: client
    )

    let result = try await service.check(currentVersion: "0.1.1")

    guard case .available(let update) = result else {
      return XCTFail("Expected a newer release")
    }
    XCTAssertEqual(update.version, "0.1.2")
    XCTAssertEqual(update.assetName, "MoaIMF-0.1.2.dmg")
    XCTAssertEqual(
      update.releaseNotes,
      """
      # MoaIMF 0.1.2

      - Improves update checks.
      - Clarifies the download flow.
      - Keeps the download button visible.
      - Shows the full release notes.
      """
    )
    XCTAssertEqual(
      client.lastDataRequest?.value(forHTTPHeaderField: "Accept"), "application/vnd.github+json")
    XCTAssertEqual(
      client.lastDataRequest?.value(forHTTPHeaderField: "X-GitHub-Api-Version"), "2022-11-28")
  }

  func testTreatsSameOrOlderReleaseAsCurrent() async throws {
    let client = FakeUpdateNetworkClient(
      data: Data(
        """
        {
          "tag_name": "release-0.1.1",
          "html_url": "https://github.com/charliehotel/MoaIMF/releases/tag/release-0.1.1",
          "draft": false,
          "prerelease": false,
          "assets": []
        }
        """.utf8
      )
    )
    let service = GitHubUpdateService(
      apiURL: URL(string: "https://example.com/releases/latest")!,
      networkClient: client
    )

    let result = try await service.check(currentVersion: "0.1.1")

    XCTAssertEqual(result, .current(latestVersion: "0.1.1"))
  }

  func testDownloadsToDownloadsDirectoryWithoutOverwritingExistingAsset() async throws {
    let fileManager = FileManager.default
    let downloadsDirectory = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: downloadsDirectory) }

    let existing = downloadsDirectory.appendingPathComponent("MoaIMF-0.1.2.dmg")
    try Data("existing".utf8).write(to: existing)

    let temporaryURL = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try Data("new update".utf8).write(to: temporaryURL)
    let client = FakeUpdateNetworkClient(downloadURL: temporaryURL)
    let service = GitHubUpdateService(
      networkClient: client,
      fileManager: fileManager,
      downloadsDirectory: downloadsDirectory
    )
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!
    )

    let downloadedURL = try await service.download(update)

    XCTAssertEqual(downloadedURL.lastPathComponent, "MoaIMF-0.1.2 (2).dmg")
    XCTAssertEqual(try Data(contentsOf: downloadedURL), Data("new update".utf8))
    XCTAssertEqual(try Data(contentsOf: existing), Data("existing".utf8))
  }

  func testRejectsDownloadedAssetWithMismatchedDigest() async throws {
    let fileManager = FileManager.default
    let downloadsDirectory = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: downloadsDirectory) }

    let temporaryURL = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    try Data("tampered".utf8).write(to: temporaryURL)
    let service = GitHubUpdateService(
      networkClient: FakeUpdateNetworkClient(downloadURL: temporaryURL),
      fileManager: fileManager,
      downloadsDirectory: downloadsDirectory
    )
    let update = AppUpdate(
      version: "0.1.2",
      tagName: "v0.1.2",
      releaseURL: URL(string: "https://example.com/release")!,
      assetName: "MoaIMF-0.1.2.dmg",
      downloadURL: URL(string: "https://example.com/MoaIMF-0.1.2.dmg")!,
      digest: "sha256:0000000000000000000000000000000000000000000000000000000000000000"
    )

    do {
      _ = try await service.download(update)
      XCTFail("Expected a checksum mismatch")
    } catch let error as AppUpdateError {
      XCTAssertEqual(error, .checksumMismatch)
    }
    XCTAssertFalse(
      fileManager.fileExists(
        atPath: downloadsDirectory.appendingPathComponent(update.assetName).path))
  }
}

@MainActor
private final class FakeUpdateNetworkClient: UpdateNetworkClient {
  let data: Data
  let dataResponse: HTTPURLResponse
  let downloadURL: URL
  let downloadResponse: HTTPURLResponse
  private(set) var lastDataRequest: URLRequest?

  init(
    data: Data = Data("{}".utf8),
    statusCode: Int = 200,
    downloadURL: URL? = nil
  ) {
    self.data = data
    dataResponse = HTTPURLResponse(
      url: URL(string: "https://example.com/api")!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )!
    self.downloadURL =
      downloadURL
      ?? FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    downloadResponse = HTTPURLResponse(
      url: URL(string: "https://example.com/download")!,
      statusCode: statusCode,
      httpVersion: nil,
      headerFields: nil
    )!
  }

  func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
    lastDataRequest = request
    return (data, dataResponse)
  }

  func download(for request: URLRequest) async throws -> (URL, HTTPURLResponse) {
    (downloadURL, downloadResponse)
  }
}
