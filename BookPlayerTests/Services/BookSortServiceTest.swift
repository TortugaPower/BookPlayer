@testable import BookPlayer
import XCTest

class BookSortServiceTest: XCTestCase {
    let unorderedBookNames = [
        "01 Book 1",
        "05 Book 1",
        "02 Book 1",
        "03 Book 1",
        "11 Book 1",
        "09 Book 1",
        "07 Book 1"
    ]
    var booksByFile: NSOrderedSet?

    override func setUp() {
        self.booksByFile = NSOrderedSet(array: self.unorderedBookNames.map { StubFactory.book(title: $0, duration: 1000) })
    }

    override func tearDown() {}

    func testSortByFileName() {
        // swiftlint:disable force_try
        let sortedBooks = try! BookSortService.sort(booksByFile!, by: .fileName)
        let bookNames = sortedBooks.map { (book) -> String in
            guard let book = book as? Book else { return "" }
            return book.originalFileName!
        }
        XCTAssert(bookNames == unorderedBookNames.sorted())
        // swiftlint:enable force_try
    }
}
