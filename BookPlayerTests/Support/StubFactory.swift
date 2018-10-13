import Foundation
@testable import BookPlayer

class StubFactory {
    public static func book(title: String, duration: Double) -> Book {
        let dummyUrl    = URL(fileURLWithPath: title)
        let bookUrl     = FileItem(originalUrl: dummyUrl, processedUrl: dummyUrl, destinationFolder: dummyUrl)
        let book        = DataManager.createBook(from: bookUrl)
        book.duration   = duration
        
        return book
    }
}
