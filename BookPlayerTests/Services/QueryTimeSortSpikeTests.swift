//
//  QueryTimeSortSpikeTests.swift
//  BookPlayerTests
//
//  Phase 0 spike for the query-time-sort refactor: proves the Core Data SQLite
//  store supports the exact descriptor recipes the refactor will ship —
//  `localizedStandardCompare:` selectors combined with `dictionaryResultType`,
//  `fetchLimit`/`fetchOffset` paging, and an `orderRank` tie-breaker — and that
//  the SQL-evaluated order matches today's in-memory `SortType.sortItems`.
//
//  If any of these fail, the refactor design pivots BEFORE any production code
//  moves. The recipes below are the source of truth for the future
//  `SortType.sortDescriptors`.
//

@testable import BookPlayerKit
import CoreData
import XCTest

final class QueryTimeSortSpikeTests: XCTestCase {
  private var storePath: String!
  private var dataManager: DataManager!

  override func setUp() {
    super.setUp()
    storePath = NSTemporaryDirectory() + "QueryTimeSortSpike-\(UUID().uuidString).sqlite"
    dataManager = DataManager(coreDataStack: CoreDataStack(testPath: storePath))
  }

  override func tearDown() {
    // The store files are left in the simulator's tmp dir on purpose: deleting
    // them while the NSPersistentContainer still holds them open trips SQLite's
    // "vnode unlinked while in use" API-violation warning.
    dataManager = nil
    super.tearDown()
  }

  // MARK: - Descriptor recipes under test (the future SortType.sortDescriptors)

  private var rankTieBreaker: NSSortDescriptor {
    NSSortDescriptor(key: "orderRank", ascending: true)
  }

  private var titleDescriptors: [NSSortDescriptor] {
    [
      NSSortDescriptor(
        key: "title",
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare(_:))
      ),
      rankTieBreaker,
    ]
  }

  private var fileNameDescriptors: [NSSortDescriptor] {
    [
      NSSortDescriptor(
        key: "originalFileName",
        ascending: true,
        selector: #selector(NSString.localizedStandardCompare(_:))
      ),
      rankTieBreaker,
    ]
  }

  private var mostRecentDescriptors: [NSSortDescriptor] {
    [
      NSSortDescriptor(key: "lastPlayDate", ascending: false),
      rankTieBreaker,
    ]
  }

  // MARK: - Seeding

  @discardableResult
  private func seedBook(
    into manager: DataManager,
    title: String,
    fileName: String? = nil,
    rank: Int16,
    lastPlayDate: Date? = nil
  ) -> Book {
    let context = manager.getContext()
    // swiftlint:disable:next force_cast
    let book = NSEntityDescription.insertNewObject(forEntityName: "Book", into: context) as! Book
    book.relativePath = "\(title)-\(rank).txt"
    book.title = title
    book.originalFileName = fileName ?? "\(title).txt"
    book.details = "spike-author"
    book.duration = 100
    book.isFinished = false
    book.lastPlayDate = lastPlayDate
    book.type = .book
    book.uuid = UUID().uuidString
    book.orderRank = rank
    return book
  }

  /// Finder-style-interesting titles, seeded with ranks that DISAGREE with every
  /// sort rule so a passing test can't be an accident of insertion order.
  private func seedStandardDataset(into manager: DataManager) {
    seedBook(into: manager, title: "09 Book 10", rank: 0)
    seedBook(into: manager, title: "banana", rank: 1)
    seedBook(into: manager, title: "01 Book 1", rank: 2)
    seedBook(into: manager, title: "Apple", rank: 3)
    seedBook(into: manager, title: "09 Book 2", rank: 4)
    seedBook(into: manager, title: "05 Book 1", rank: 5)
    seedBook(into: manager, title: "cherry", rank: 6)
    manager.saveContext()
  }

  // MARK: - Fetch helpers

  /// The production render-fetch shape: dictionaryResultType + propertiesToFetch,
  /// exactly like `buildListContentsFetchRequest`.
  private func dictionaryFetchTitles(
    from manager: DataManager,
    sortedBy descriptors: [NSSortDescriptor],
    limit: Int? = nil,
    offset: Int? = nil
  ) throws -> [String] {
    let request = NSFetchRequest<NSDictionary>(entityName: "Book")
    request.resultType = .dictionaryResultType
    request.propertiesToFetch = [
      "title",
      "orderRank",
    ]
    request.sortDescriptors = descriptors
    if let limit {
      request.fetchLimit = limit
    }
    if let offset {
      request.fetchOffset = offset
    }
    let results = try manager.getContext().fetch(request)
    return results.compactMap { $0["title"] as? String }
  }

  private func managedFetch(
    from manager: DataManager,
    sortedBy descriptors: [NSSortDescriptor]
  ) throws -> [BookPlayerKit.LibraryItem] {
    let request = NSFetchRequest<BookPlayerKit.LibraryItem>(entityName: "Book")
    request.sortDescriptors = descriptors
    return try manager.getContext().fetch(request)
  }

  // MARK: - Selector support + parity with today's in-memory comparator

  func testTitleSortMatchesInMemoryComparator_dictionaryResultType() throws {
    seedStandardDataset(into: dataManager)

    let sqlOrder = try dictionaryFetchTitles(from: dataManager, sortedBy: titleDescriptors)
    let inMemoryOrder = SortType.metadataTitle
      .sortItems(try managedFetch(from: dataManager, sortedBy: [rankTieBreaker]))
      .map { $0.title ?? "" }

    // Absolute assertions on the locale-independent (numeric-awareness) part:
    let numericTitles = sqlOrder.filter { $0.hasPrefix("0") }
    XCTAssertEqual(numericTitles, ["01 Book 1", "05 Book 1", "09 Book 2", "09 Book 10"])
    // Parity with SortType.sortItems is the actual refactor claim:
    XCTAssertEqual(sqlOrder, inMemoryOrder)
  }

  func testFileNameSortMatchesInMemoryComparator() throws {
    seedStandardDataset(into: dataManager)

    let request = NSFetchRequest<NSDictionary>(entityName: "Book")
    request.resultType = .dictionaryResultType
    request.propertiesToFetch = ["originalFileName"]
    request.sortDescriptors = fileNameDescriptors
    let sqlOrder = try dataManager.getContext().fetch(request)
      .compactMap { $0["originalFileName"] as? String }

    let inMemoryOrder = SortType.fileName
      .sortItems(try managedFetch(from: dataManager, sortedBy: [rankTieBreaker]))
      .map { $0.originalFileName ?? "" }

    XCTAssertEqual(sqlOrder, inMemoryOrder)
  }

  func testMostRecentSortPutsNeverPlayedLast() throws {
    let now = Date()
    seedBook(into: dataManager, title: "never-played-a", rank: 0, lastPlayDate: nil)
    seedBook(into: dataManager, title: "oldest", rank: 1, lastPlayDate: now.addingTimeInterval(-300))
    seedBook(into: dataManager, title: "newest", rank: 2, lastPlayDate: now)
    seedBook(into: dataManager, title: "never-played-b", rank: 3, lastPlayDate: nil)
    seedBook(into: dataManager, title: "middle", rank: 4, lastPlayDate: now.addingTimeInterval(-100))
    dataManager.saveContext()

    let sqlOrder = try dictionaryFetchTitles(from: dataManager, sortedBy: mostRecentDescriptors)

    // SQLite sorts NULL last under DESC, matching sortItems' `?? .distantPast`.
    // The two never-played rows tie and fall back to rank order.
    XCTAssertEqual(sqlOrder, ["newest", "middle", "oldest", "never-played-a", "never-played-b"])

    let inMemoryOrder = SortType.mostRecent
      .sortItems(try managedFetch(from: dataManager, sortedBy: [rankTieBreaker]))
      .map { $0.title ?? "" }
    XCTAssertEqual(sqlOrder, inMemoryOrder)
  }

  // MARK: - Determinism: the tie-breaker today's in-memory sort doesn't have

  func testEqualSortKeysFallBackToRankOrder() throws {
    seedBook(into: dataManager, title: "Same Title", fileName: "d.txt", rank: 3)
    seedBook(into: dataManager, title: "Same Title", fileName: "a.txt", rank: 0)
    seedBook(into: dataManager, title: "Same Title", fileName: "c.txt", rank: 2)
    seedBook(into: dataManager, title: "Same Title", fileName: "b.txt", rank: 1)
    dataManager.saveContext()

    let request = NSFetchRequest<NSDictionary>(entityName: "Book")
    request.resultType = .dictionaryResultType
    request.propertiesToFetch = ["originalFileName"]
    request.sortDescriptors = titleDescriptors

    // Deterministic across repeated fetches — the property the unstable
    // in-memory sort can't promise.
    for _ in 0..<3 {
      let order = try dataManager.getContext().fetch(request)
        .compactMap { $0["originalFileName"] as? String }
      XCTAssertEqual(order, ["a.txt", "b.txt", "c.txt", "d.txt"])
    }
  }

  // MARK: - Pagination

  func testPaginationIsStableUnderTitleSort() throws {
    // 30 titles whose alphabetical and rank orders disagree everywhere.
    let count = 30
    for index in 0..<count {
      let title = String(format: "Book %03d", (index * 7) % count)
      seedBook(into: dataManager, title: title, rank: Int16(count - index))
    }
    dataManager.saveContext()

    let fullOrder = try dictionaryFetchTitles(from: dataManager, sortedBy: titleDescriptors)
    XCTAssertEqual(fullOrder.count, count)

    let pageSize = 13
    var paged: [String] = []
    var offset = 0
    while true {
      let page = try dictionaryFetchTitles(
        from: dataManager,
        sortedBy: titleDescriptors,
        limit: pageSize,
        offset: offset
      )
      paged.append(contentsOf: page)
      offset += page.count
      if page.count < pageSize { break }
    }

    XCTAssertEqual(paged, fullOrder, "paged walk must equal the unpaged order — no gaps, no duplicates")
  }

  // MARK: - Harness fidelity: the /dev/null pattern behaves like a real store

  func testDevNullStoreParityWithRealSQLiteFile() throws {
    seedStandardDataset(into: dataManager)
    let realStoreOrder = try dictionaryFetchTitles(from: dataManager, sortedBy: titleDescriptors)

    let devNullManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    seedStandardDataset(into: devNullManager)
    let devNullOrder = try dictionaryFetchTitles(from: devNullManager, sortedBy: titleDescriptors)

    XCTAssertEqual(devNullOrder, realStoreOrder)
  }

  // MARK: - Managed-object fetches (the reorder/reverse paths) support the selector too

  func testManagedObjectFetchSupportsSelectorSort() throws {
    seedStandardDataset(into: dataManager)

    let managedOrder = try managedFetch(from: dataManager, sortedBy: titleDescriptors)
      .map { $0.title ?? "" }
    let dictionaryOrder = try dictionaryFetchTitles(from: dataManager, sortedBy: titleDescriptors)

    XCTAssertEqual(managedOrder, dictionaryOrder)
  }
}
