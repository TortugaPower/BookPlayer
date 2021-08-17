@testable import BookPlayer
@testable import BookPlayerKit
import Foundation

class StubFactory {
    public static func book(title: String, duration: Double, metaDataTitle: String? = nil) -> Book {
      let filename = "\(title).txt"
      let bookContents = "bookcontents".data(using: .utf8)!
      let processedFolder = DataManager.getProcessedFolderURL()

      // Add test file to Processed folder
      let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

      let book = DataManager.createBook(from: fileUrl)
      book.duration = duration

      return book
    }

    class func folder(title: String) throws -> Folder {
      let folder = DataManager.createFolder(title: title)

      let processedFolder = DataManager.getProcessedFolderURL()

      _ = try DataTestUtils.generateTestFolder(name: title, destinationFolder: processedFolder)

      return folder
    }

  class func library() throws -> Library {
    return try DataManager.getLibrary() ?? Library.create(in: DataManager.getContext())
  }
}
