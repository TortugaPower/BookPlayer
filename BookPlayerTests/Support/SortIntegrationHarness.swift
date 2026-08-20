//
//  SortIntegrationHarness.swift
//  BookPlayerTests
//
//  A LibraryService wired to a REAL PreferencesSyncService over an isolated
//  UserDefaults suite — the integration seam for sticky-sort behavior, where the
//  preference layer's real resolution rules (SortLocation gates, key routing)
//  apply instead of a mock's canned answers.
//
//  `bootstrap()` is deliberately never called: no KVO, no network, no dirty
//  list — only the resolver surface (`setSort`/`effectiveSort`) that the
//  LibraryService hooks consume.
//
//  The store is a real SQLite file in a per-instance temp location (not the
//  usual `/dev/null`) because sync-path tests write on the background context
//  and read back on the view context; a real store keeps that path
//  production-faithful. Call `tearDown()` from the test's `tearDown`.
//

@testable import BookPlayer
@testable import BookPlayerKit
import CoreData
import Foundation

final class SortIntegrationHarness {
  let dataManager: DataManager
  let libraryService: LibraryService
  let preferences: PreferencesSyncService
  let defaults: UserDefaults

  private let suiteName: String
  private let storePath: String

  init() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())

    storePath = NSTemporaryDirectory() + "SortIntegrationHarness-\(UUID().uuidString).sqlite"
    dataManager = DataManager(coreDataStack: CoreDataStack(testPath: storePath))
    libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: AudioMetadataService())
    _ = libraryService.getLibrary()

    suiteName = "SortIntegrationHarness.\(UUID().uuidString)"
    defaults = UserDefaults(suiteName: suiteName)!
    preferences = PreferencesSyncService()
    preferences.setup(
      accountService: AccountServiceMock(account: nil),
      libraryService: libraryService,
      defaults: defaults,
      client: NetworkClientMock(mockedResponse: Empty())
    )
    libraryService.preferencesService = preferences
  }

  func tearDown() {
    defaults.removePersistentDomain(forName: suiteName)
    // The store files are left in the simulator's tmp dir on purpose: deleting
    // them while the NSPersistentContainer still holds them open trips SQLite's
    // "vnode unlinked while in use" API-violation warning.
  }

  // MARK: - Seeding

  /// Inserts a Book row directly (no file on disk). Ranks are the caller's
  /// responsibility so tests can seed adversarial arrangements.
  @discardableResult
  func seedBook(
    relativePath: String,
    title: String? = nil,
    rank: Int16,
    into folder: Folder? = nil,
    isFinished: Bool = false,
    lastPlayDate: Date? = nil,
    duration: Double = 100
  ) -> Book {
    let context = dataManager.getContext()
    // swiftlint:disable:next force_cast
    let book = NSEntityDescription.insertNewObject(forEntityName: "Book", into: context) as! Book
    book.relativePath = relativePath
    book.title = title ?? relativePath
    book.originalFileName = (relativePath as NSString).lastPathComponent
    book.details = "seed-author"
    book.duration = duration
    book.isFinished = isFinished
    book.lastPlayDate = lastPlayDate
    book.type = .book
    book.uuid = UUID().uuidString
    book.orderRank = rank
    if let folder {
      folder.addToItems(book)
    } else {
      libraryService.getLibraryReference().addToItems(book)
    }
    return book
  }

  /// Inserts a Folder row at the root. Pass a placeholder `uuid` (or `""`) to
  /// produce an `.unresolved` location; pass `type: .bound` for a bound book.
  @discardableResult
  func seedFolder(
    relativePath: String,
    rank: Int16,
    uuid: String? = nil,
    type: SimpleItemType = .folder
  ) -> Folder {
    let folder = Folder(title: relativePath, context: dataManager.getContext())
    if let uuid {
      folder.uuid = uuid
    }
    folder.type = type.itemType
    folder.orderRank = rank
    libraryService.getLibraryReference().addToItems(folder)
    return folder
  }

  func save() {
    dataManager.saveContext()
  }

  // MARK: - Observations

  /// The order the list UI would render (fetchContents is the render fetch).
  func renderedOrder(at relativePath: String? = nil) -> [String] {
    let contents = libraryService.fetchContents(at: relativePath, limit: nil, offset: nil) ?? []
    return contents.map(\.relativePath)
  }

  /// The persisted rank column, keyed by relativePath, fetched fresh from the store.
  func rankColumn(at relativePath: String? = nil) -> [String: Int16] {
    let contents = libraryService.fetchContents(at: relativePath, limit: nil, offset: nil) ?? []
    return Dictionary(uniqueKeysWithValues: contents.map { ($0.relativePath, $0.orderRank) })
  }

  /// True when any `library_sort:*` key was persisted in the isolated suite.
  var hasAnySortPreferencePersisted: Bool {
    defaults.dictionaryRepresentation().keys.contains {
      $0.hasPrefix(Constants.UserDefaults.librarySortPrefix)
    }
  }
}
