import Foundation
public extension URL {
  /// Isolates and returns a filename string from a `URL`
  var fileName: String {
    return self.deletingPathExtension().lastPathComponent
  }

  /// Canonical form used for media-server connection deduplication. Two URLs that point at the
  /// same server but differ only in trivial ways — scheme/host case, default ports, trailing
  /// slash — collapse to the same canonical string here.
  ///
  /// Used by `JellyfinConnectionService` and `AudiobookShelfConnectionService` to dedupe saved
  /// connections so the user doesn't end up with two entries for one server when they re-type
  /// the URL after a token expiry (or add the same server from two slightly-different inputs).
  var canonicalDedupKey: String {
    guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
      return absoluteString
    }
    components.scheme = components.scheme?.lowercased()
    components.host = components.host?.lowercased()
    components.user = nil
    components.password = nil
    components.fragment = nil
    components.query = nil

    if let port = components.port,
       (components.scheme == "http" && port == 80)
       || (components.scheme == "https" && port == 443) {
      components.port = nil
    }

    // Trim any trailing slash, including the root "/". Without this, `https://example.com`
    // and `https://example.com/` produced different canonical keys, defeating dedup for
    // the most common user variation.
    while components.path.hasSuffix("/") {
      components.path.removeLast()
    }

    return components.url?.absoluteString ?? absoluteString
  }

  func relativePath(to baseURL: URL) -> String {
    let lastPath = self.path.components(separatedBy: baseURL.path).last ?? ""
    if !lastPath.isEmpty,
       lastPath.first == "/" {
      return String(lastPath.dropFirst())
    } else {
      return lastPath
    }
  }

  var isDirectoryFolder: Bool {
    return (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
  }

  // Disable file protection for file and descendants if it's a directory
  func disableFileProtection() {
    try? (self as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
    try? (self as NSURL).setResourceValue(false, forKey: .isUserImmutableKey)

    guard self.isDirectoryFolder else { return }

    let enumerator = FileManager.default.enumerator(at: self,
                                                    includingPropertiesForKeys: [.isDirectoryKey],
                                                    options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
      print("directoryEnumerator error at \(url): ", error)
      return true
    })!

    for case let fileURL as URL in enumerator {
      try? (fileURL as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
      try? (fileURL as NSURL).setResourceValue(false, forKey: .isUserImmutableKey)
    }
  }

  func hasAppKey() -> Bool {
    do {
      _ = try self.extendedAttribute(forName: "\(Bundle.main.configurationString(for: .bundleIdentifier)).identifier")
      return true
    } catch {
      return false
    }
  }

  func getAppOrderRank() -> Int? {
    do {
      let data = try self.extendedAttribute(forName: "\(Bundle.main.configurationString(for: .bundleIdentifier)).identifier")
      return data.withUnsafeBytes { $0.load(as: Int.self) }
    } catch {
      return nil
    }
  }

  func setAppOrderRank(_ rank: Int) throws {
    let data = withUnsafeBytes(of: rank) { Data($0) }

    try self.withUnsafeFileSystemRepresentation { fileSystemPath in
      let result = data.withUnsafeBytes {
        setxattr(fileSystemPath, "\(Bundle.main.configurationString(for: .bundleIdentifier)).identifier", $0.baseAddress, data.count, 0, 0)
      }
      guard result >= 0 else { throw URL.posixError(errno) }
    }
  }

  /// Get extended attribute.
  func extendedAttribute(forName name: String) throws -> Data {
    let data = try self.withUnsafeFileSystemRepresentation { fileSystemPath -> Data in

      // Determine attribute size:
      let length = getxattr(fileSystemPath, name, nil, 0, 0, 0)
      guard length >= 0 else { throw URL.posixError(errno) }

      // Create buffer with required size:
      var data = Data(count: length)

      // Retrieve attribute:
      let result = data.withUnsafeMutableBytes { [count = data.count] in
        getxattr(fileSystemPath, name, $0.baseAddress, count, 0, 0)
      }
      guard result >= 0 else { throw URL.posixError(errno) }
      return data
    }
    return data
  }

  /// Set extended attribute.
  func setExtendedAttribute(data: Data, forName name: String) throws {
    try self.withUnsafeFileSystemRepresentation { fileSystemPath in
      let result = data.withUnsafeBytes {
        setxattr(fileSystemPath, name, $0.baseAddress, data.count, 0, 0)
      }
      guard result >= 0 else { throw URL.posixError(errno) }
    }
  }

  /// Remove extended attribute.
  func removeExtendedAttribute(forName name: String) throws {
    try self.withUnsafeFileSystemRepresentation { fileSystemPath in
      let result = removexattr(fileSystemPath, name, 0)
      guard result >= 0 else { throw URL.posixError(errno) }
    }
  }

  /// Helper function to create an NSError from a Unix errno.
  private static func posixError(_ err: Int32) -> NSError {
    return NSError(domain: NSPOSIXErrorDomain, code: Int(err),
                   userInfo: [NSLocalizedDescriptionKey: String(cString: strerror(err))])
  }
}
