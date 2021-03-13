import Foundation
public extension URL {
    /// Isolates and returns a filename string from a `URL`
    var fileName: String {
        let filename = self.deletingPathExtension().lastPathComponent
        return filename
    }

    func relativePath(to baseURL: URL) -> String {
        return self.path.components(separatedBy: baseURL.path).last ?? ""
    }

    func hasAppKey() -> Bool {
        do {
            _ = try self.extendedAttribute(forName: "com.tortugapower.audiobookplayer.identifier")
            return true
        } catch {
            return false
        }
    }

    func getAppIdentifier() -> String? {
        do {
            let data = try self.extendedAttribute(forName: "com.tortugapower.audiobookplayer.identifier")
            return String(bytes: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    func setAppIdentifier(_ identifier: String) throws {
        guard let data = identifier.data(using: .utf8) else {
            throw "derp"
        }

        try self.withUnsafeFileSystemRepresentation { fileSystemPath in
            let result = data.withUnsafeBytes {
                setxattr(fileSystemPath, "com.tortugapower.audiobookplayer.identifier", $0.baseAddress, data.count, 0, 0)
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
