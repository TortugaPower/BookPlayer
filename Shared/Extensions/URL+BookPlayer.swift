import Foundation
public extension URL {
    /// Isolates and returns a filename string from a `URL`
    var fileName: String {
        get {
            let filename = self.deletingPathExtension().lastPathComponent
            return filename
        }
    }
}
