import Foundation
import UniformTypeIdentifiers

public extension URL {
  /// The `UTType` inferred from this URL's path extension, if the extension maps to one.
  /// Nil when there's no extension or it doesn't correspond to a known type.
  var fileType: UTType? {
    UTType(filenameExtension: pathExtension)
  }

  /// Isolates and returns a filename string from a `URL`
  var fileName: String {
    return self.deletingPathExtension().lastPathComponent
  }

  /// Canonical form of a media-server address. Two URLs that point at the same server but
  /// differ only in trivial ways — scheme/host case, default ports, trailing slash — collapse
  /// to the same string here.
  ///
  /// Used by `JellyfinConnectionService` and `AudiobookShelfConnectionService` to dedupe saved
  /// connections so the user doesn't end up with two entries for one server when they re-type
  /// the URL after a token expiry (or add the same server from two slightly-different inputs).
  ///
  /// It is also the `hostId` synced on every AudiobookShelf book (and a Jellyfin book whose
  /// server never reported an id), so it is a cross-platform contract: Android's
  /// `ExternalServiceUtils.canonicalServerKey` must produce the same key from the same address.
  /// Android's keys are already stored, so this mirrors its algorithm, including how Android's
  /// own `java.net.URI` parses a host:
  /// - lowercase scheme and host; no user info, query or fragment; no default port;
  /// - the path percent-DECODED, with trailing slashes trimmed;
  /// - an address that URI gives no host (a label starting with `_`, say) keeps its whole
  ///   string, lowercased, minus trailing slashes.
  var canonicalDedupKey: String {
    let raw = absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
    var fallback = raw.lowercased()
    while fallback.hasSuffix("/") {
      fallback.removeLast()
    }

    guard
      let components = URLComponents(string: raw),
      let scheme = components.scheme?.lowercased(),
      // Punycode, as Foundation stores an internationalized host. Android keeps such a host
      // as typed, so only an address typed there in punycode gets the same key; one typed in
      // Unicode keys its whole string on Android and won't match (accepted: rare for a server).
      let host = components.encodedHost,
      Self.isServerBasedHost(host)
    else {
      return fallback
    }

    // Android's rule exactly: 443 for https, 80 for anything else.
    let defaultPort = scheme == "https" ? 443 : 80
    let port = components.port.map { $0 == defaultPort ? "" : ":\($0)" } ?? ""

    var path = components.path
    while path.hasSuffix("/") {
      path.removeLast()
    }

    return "\(scheme)://\(host.lowercased())\(port)\(path)"
  }

  /// Whether Android's `java.net.URI` parses `host` as a server-based host, the only kind it
  /// reports a host for: an IPv6 literal, an IPv4 address, or a hostname. Android's hostname is
  /// RFC 2396's plus underscores: each label starts with an ASCII letter or digit, goes on with
  /// letters, digits, `-` and `_`, and doesn't end in `-`; when there are several, the last
  /// starts with a letter; one trailing dot is allowed. (The desktop JVM rejects underscores,
  /// so a JVM unit test of Android's function can't show this.) Anything else, like a
  /// percent-escape, it reads as a registry name with no host.
  private static func isServerBasedHost(_ host: String) -> Bool {
    if host.hasPrefix("[") {
      return true
    }

    let isDigit = { (character: Character) in character.isASCII && character.isNumber }
    let isLetter = { (character: Character) in character.isASCII && character.isLetter }

    let octets = host.split(separator: ".", omittingEmptySubsequences: false)
    if octets.count == 4,
      octets.allSatisfy({ !$0.isEmpty && $0.allSatisfy(isDigit) && (Int($0) ?? 256) <= 255 })
    {
      return true
    }

    var labels = octets
    if labels.count > 1, labels.last?.isEmpty == true {
      labels.removeLast()
    }

    let labelsAreValid = labels.allSatisfy { label in
      guard let first = label.first, let last = label.last else { return false }
      return (isDigit(first) || isLetter(first)) && last != "-"
        && label.allSatisfy { isDigit($0) || isLetter($0) || $0 == "-" || $0 == "_" }
    }

    guard labelsAreValid, let lastLabel = labels.last else { return false }

    return labels.count == 1 || lastLabel.first.map(isLetter) == true
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
