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
        return DataManager.createFolder(title: title, items: items)
    }
}
