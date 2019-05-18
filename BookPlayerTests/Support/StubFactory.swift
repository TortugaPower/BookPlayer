@testable import BookPlayer
import Foundation

class StubFactory {
    public static func book(title: String, duration: Double, metaDataTitle: String? = nil) -> Book {
        let dummyUrl = URL(fileURLWithPath: title)
        let bookUrl = FileItem(originalUrl: dummyUrl, processedUrl: dummyUrl, destinationFolder: dummyUrl)
        let book = DataManager.createBook(from: bookUrl)
        book.duration = duration

        return book
    }
}
