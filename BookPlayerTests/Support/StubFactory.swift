@testable import BookPlayer
@testable import BookPlayerKit
import Foundation

class StubFactory {
    public static func book(title: String, duration: Double, metaDataTitle: String? = nil) -> Book {
        let dummyUrl = URL(fileURLWithPath: title)
        let book = DataManager.createBook(from: dummyUrl)
        book.duration = duration

        return book
    }

    class func folder(title: String, items: [LibraryItem]) -> Folder {
      let folder = DataManager.createFolder(title: title)

      for item in items {
        folder.insert(item: item)
      }

      return folder
    }
}
