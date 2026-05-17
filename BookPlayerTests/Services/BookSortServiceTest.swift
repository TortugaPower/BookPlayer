@testable import BookPlayer
@testable import BookPlayerKit
import CoreData
import XCTest

class BookSortServiceTest: XCTestCase {
  let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))

  let unorderedBookNames = [
    "05 Book 1",
    "01 Book 1",
    "09 Book 10",
    "09 Book 2"
  ]

  let orderedBookNames = [
    "01 Book 1.txt",
    "05 Book 1.txt",
    "09 Book 2.txt",
    "09 Book 10.txt"
  ]

  var booksByFile: [BookPlayerKit.LibraryItem]?

  override func setUp() {
    let documentsFolder = DataManager.getDocumentsFolderURL()
    DataTestUtils.clearFolderContents(url: documentsFolder)
    let processedFolder = DataManager.getProcessedFolderURL()
    DataTestUtils.clearFolderContents(url: processedFolder)

    self.booksByFile = self.unorderedBookNames
      .map { StubFactory.book(dataManager: self.dataManager, title: $0, duration: 1000) }
  }

  override func tearDown() {}

  func testSortByFileName() {
    let sortedBooks = SortType.fileName.sortItems(self.booksByFile!)
    let bookNames = sortedBooks.map { (book) -> String in
      guard let book = book as? Book else { return "" }
      return book.originalFileName!
    }

    XCTAssert(bookNames == self.orderedBookNames)
  }
}

class LibraryReverseContentsTest: XCTestCase {
  var sut: LibraryService!
  var prefsMock: PreferencesSyncServiceProtocolMock!

  override func setUp() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    sut = LibraryService()
    sut.setup(dataManager: dataManager, audioMetadataService: AudioMetadataService())
    _ = sut.getLibrary()
    prefsMock = PreferencesSyncServiceProtocolMock()
    prefsMock.effectiveSortForLocationReturnValue = .custom
    sut.preferencesService = prefsMock
  }

  /// Adds books with the given `originalFileName`s to the library root in order, with
  /// monotonic `orderRank` values starting at 0. Returns them in insertion order.
  @discardableResult
  private func seedLibraryRoot(with names: [String]) -> [Book] {
    let library = sut.getLibraryReference()
    let books = names.enumerated().map { index, name -> Book in
      let book = StubFactory.book(dataManager: sut.dataManager, title: name, duration: 100)
      book.orderRank = Int16(index)
      library.addToItems(book)
      return book
    }
    sut.dataManager.saveContext()
    return books
  }

  private func libraryRootBookNames() -> [String] {
    let request: NSFetchRequest<Book> = NSFetchRequest(entityName: "Book")
    request.predicate = NSPredicate(format: "folder == nil")
    request.sortDescriptors = [NSSortDescriptor(key: "orderRank", ascending: true)]
    let books = (try? sut.dataManager.getContext().fetch(request)) ?? []
    return books.map { $0.title ?? "" }
  }

  func testReverseFlipsOrderRank() {
    seedLibraryRoot(with: ["Alpha", "Bravo", "Charlie", "Delta"])

    sut.reverseContents(at: nil)

    XCTAssertEqual(libraryRootBookNames(), ["Delta", "Charlie", "Bravo", "Alpha"])
  }

  func testReverseTransitionsStickyToCustom() {
    seedLibraryRoot(with: ["Alpha", "Bravo", "Charlie"])

    sut.reverseContents(at: nil)

    XCTAssertEqual(prefsMock.setSortForLocationCallsCount, 1)
    let invocation = prefsMock.setSortForLocationReceivedArguments
    XCTAssertEqual(invocation?.value, .custom)
    XCTAssertEqual(invocation?.location, .libraryRoot)
  }

  func testReverseFromAutomaticAlsoTransitionsToCustom() {
    seedLibraryRoot(with: ["Alpha", "Bravo", "Charlie"])
    prefsMock.effectiveSortForLocationReturnValue = .automatic(.metadataTitle)

    sut.reverseContents(at: nil)

    XCTAssertEqual(prefsMock.setSortForLocationReceivedArguments?.value, .custom)
    XCTAssertEqual(libraryRootBookNames(), ["Charlie", "Bravo", "Alpha"])
  }

  func testReverseOnEmptyLibraryDoesNotChangeOrderRank() {
    sut.reverseContents(at: nil)

    XCTAssertEqual(libraryRootBookNames(), [])
    // Pref write still fires (it precedes the empty guard, matching reorderItems).
    XCTAssertEqual(prefsMock.setSortForLocationCallsCount, 1)
  }
}
