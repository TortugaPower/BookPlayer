@testable import BookPlayer
@testable import BookPlayerKit
import Foundation

class StubFactory {
  public class func book(dataManager: DataManager, title: String, duration: Double) -> Book {
    let filename = "\(title).txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Processed folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let book = dataManager.createBook(from: fileUrl)
    book.duration = duration

    return book
  }

  public class func folder(dataManager: DataManager, title: String) throws -> Folder {
    let folder = dataManager.createFolder(title: title)

    let processedFolder = DataManager.getProcessedFolderURL()

    _ = try DataTestUtils.generateTestFolder(name: title, destinationFolder: processedFolder)

    return folder
  }

  public class func library(dataManager: DataManager) -> Library {
    let libraryService = LibraryService(dataManager: dataManager)
    return libraryService.getLibrary()
  }
}
