import Foundation
public extension URL {
    /// Isolates and returns a filename string from a `URL`
    var fileName: String {
      return self.deletingPathExtension().lastPathComponent
    }

    func relativePath(to baseURL: URL) -> String {
        return self.path.components(separatedBy: baseURL.path).last ?? ""
    }

    var isDirectoryFolder: Bool {
        return (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
    
    var isInProcessedFolder: Bool {
        let absoluteUrl = resolvingSymlinksInPath().absoluteString
        let processedFolderUrl = DataManager.getProcessedFolderURL().absoluteString
        return absoluteUrl.contains(processedFolderUrl)
    }

  // Disable file protection for file and descendants if it's a directory
  func disableFileProtection() {
    try? (self as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)

    guard self.isDirectoryFolder else { return }

    let enumerator = FileManager.default.enumerator(at: self,
                                                    includingPropertiesForKeys: [.isDirectoryKey],
                                                    options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
                                                      print("directoryEnumerator error at \(url): ", error)
                                                      return true
                                                    })!

    for case let fileURL as URL in enumerator {
      try? (fileURL as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
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
