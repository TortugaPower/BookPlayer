@testable import BookPlayer
import XCTest

class BookSortServiceTest: XCTestCase {
    let unorderedBookNames = [
        "05 Book 1",
        "01 Book 1",
        "09 Book 10",
        "09 Book 2"
    ]

    let orderedBookNames = [
        "01 Book 1",
        "05 Book 1",
        "09 Book 2",
        "09 Book 10"
    ]

    var booksByFile: NSOrderedSet?

    override func setUp() {
        self.booksByFile = NSOrderedSet(array: self.unorderedBookNames.map { StubFactory.book(title: $0, duration: 1000) })
    }

    override func tearDown() {}

    func testSortByFileName() {
        let sortedBooks = BookSortService.sort(booksByFile!, by: .fileName)
        let bookNames = sortedBooks.map { (book) -> String in
            guard let book = book as? Book else { return "" }
            return book.originalFileName!
        }

        XCTAssert(bookNames == orderedBookNames)
        // swiftlint:enable force_try
    }
}
