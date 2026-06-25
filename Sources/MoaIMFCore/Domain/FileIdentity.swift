public struct FileIdentity: Hashable, Sendable, Codable {
  public let volume: String
  public let resource: String

  public init(volume: String, resource: String) {
    self.volume = volume
    self.resource = resource
  }
}
