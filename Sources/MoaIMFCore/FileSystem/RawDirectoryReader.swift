import Darwin
import Foundation

struct RawDirectoryReader: Sendable {
  func names(in directory: URL) throws -> [String] {
    try directory.withUnsafeFileSystemRepresentation { path in
      guard let path else { throw POSIXError(.EINVAL) }
      guard let stream = Darwin.opendir(path) else {
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
      }
      defer { Darwin.closedir(stream) }

      var names: [String] = []
      while let entry = Darwin.readdir(stream) {
        let length = Int(entry.pointee.d_namlen)
        let bytes = withUnsafeBytes(of: &entry.pointee.d_name) { Array($0.prefix(length)) }
        let name = String(decoding: bytes, as: UTF8.self)
        if name != "." && name != ".." { names.append(name) }
      }
      return names
    }
  }
}
