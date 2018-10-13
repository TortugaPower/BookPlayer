import XCTest
@testable import BookPlayer

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
    var booksByFile: [Book]?

    override func setUp() {
        booksByFile = unorderedBookNames.map { StubFactory.book(title: $0, duration: 1000) }
    }

    override func tearDown() {
    }

    func testSortByFileName() {
        // swiftlint:disable force_try
        let sortedBooks = try! BookSortService(books: booksByFile!).perform(filter: .metadataTitle)
        let bookNames = sortedBooks.map { $0.originalFileName! }
        XCTAssert(bookNames == unorderedBookNames.sorted())
        // swiftlint:enable force_try
    }
}
