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
    book.details = "test-author"
    book.relativePath = fileUrl.relativePath(to: DataManager.getProcessedFolderURL())
    
    book.title = title
    book.originalFileName = fileUrl.lastPathComponent
    book.isFinished = false
    book.duration = duration
    book.type = .book
    
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
    chapter.start = 0
    chapter.duration = 0
    chapter.title = "test"
    return chapter
  }
  
  public class func library(dataManager: DataManager) -> Library {
    let libraryService = LibraryService(dataManager: dataManager)
    return libraryService.getLibrary()
  }
}
