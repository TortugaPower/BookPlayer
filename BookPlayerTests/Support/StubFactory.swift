@testable import BookPlayerKit
import CoreData
import Foundation

class StubFactory {
  public class func book(dataManager: DataManager, title: String, duration: Double) -> Book {
    let filename = "\(title).txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Processed folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    // swiftlint:disable:next force_cast
    let book = NSEntityDescription.insertNewObject(forEntityName: "Book", into: dataManager.getContext()) as! Book
    book.author = "test-author"
    book.ext = fileUrl.pathExtension
    book.identifier = fileUrl.lastPathComponent
    book.relativePath = fileUrl.relativePath(to: DataManager.getProcessedFolderURL())

    book.title = fileUrl.lastPathComponent.replacingOccurrences(of: "_", with: " ")
    book.originalFileName = fileUrl.lastPathComponent
    book.isFinished = false
    book.duration = duration

    return book
  }

  public class func folder(dataManager: DataManager, title: String) throws -> Folder {
    let folder = Folder(title: title, context: dataManager.getContext())

    let processedFolder = DataManager.getProcessedFolderURL()

    _ = try DataTestUtils.generateTestFolder(name: title, destinationFolder: processedFolder)

    return folder
  }

  public class func folder(dataManager: DataManager,
                           title: String,
                           destinationFolder: URL) throws -> Folder {
    let folder = Folder(title: title, context: dataManager.getContext())

    let newURL = try DataTestUtils.generateTestFolder(name: title, destinationFolder: destinationFolder)

    folder.relativePath = newURL.relativePath(to: DataManager.getProcessedFolderURL())

    return folder
  }

  public class func chapter(dataManager: DataManager,
                            index: Int16) -> Chapter {
    // swiftlint:disable:next force_cast
    let chapter = NSEntityDescription.insertNewObject(forEntityName: "Chapter", into: dataManager.getContext()) as! Chapter
    chapter.index = index
    chapter.duration = 0
    return chapter
  }

  public class func library(dataManager: DataManager) -> Library {
    let libraryService = LibraryService(dataManager: dataManager)
    return libraryService.getLibrary()
  }
}
