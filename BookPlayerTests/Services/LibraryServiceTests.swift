//
//  LibraryServiceTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 11/21/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class LibraryServiceTests: XCTestCase {
  var sut: LibraryService!

  override func setUp() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    self.sut = LibraryService(dataManager: dataManager)
  }

  func testGetNewLibrary() {
    let library = self.sut.getLibrary()
    XCTAssert(library.items!.array.isEmpty)
  }

  func testGetExistingLibrary() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let newLibrary = self.sut.createLibrary()
    newLibrary.insert(item: book)

    let loadedLibrary = self.sut.getLibrary()
    XCTAssert(!loadedLibrary.items!.array.isEmpty)
  }

  func testGetEmptyLibraryLastItem() {
    let lastBook = try! self.sut.getLibraryLastItem()
    XCTAssert(lastBook == nil)
  }

  func testGetLibraryLastBook() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let newLibrary = self.sut.createLibrary()
    XCTAssert(newLibrary.lastPlayedItem == nil)
    newLibrary.lastPlayedItem = book
    newLibrary.insert(item: book)

    self.sut.dataManager.saveContext()

    let lastBook = try! self.sut.getLibraryLastItem()
    XCTAssert(lastBook?.relativePath == book.relativePath)
  }

  func testGetLibraryCurrentTheme() {
    XCTAssert(try! self.sut.getLibraryCurrentTheme() == nil)

    let theme = Theme(context: self.sut.dataManager.getContext())
    theme.title = "theme-test"

    let newLibrary = self.sut.createLibrary()
    XCTAssert(newLibrary.currentTheme == nil)
    newLibrary.currentTheme = theme

    self.sut.dataManager.saveContext()

    let currentTheme = try! self.sut.getLibraryCurrentTheme()
    XCTAssert(currentTheme?.title == theme.title)
  }

  func testGetTheme() {
    XCTAssert(self.sut.getTheme(with: "theme-test") == nil)

    let theme = Theme(context: self.sut.dataManager.getContext())
    theme.title = "theme-test"

    self.sut.dataManager.saveContext()

    XCTAssert(self.sut.getTheme(with: "theme-test") != nil)
  }

  func testSetLibraryTheme() {
    let library = self.sut.getLibrary()
    XCTAssert(library.currentTheme == nil)

    let theme = Theme(context: self.sut.dataManager.getContext())
    theme.title = "theme-test"

    self.sut.setLibraryTheme(with: "theme-test")
    self.sut.dataManager.saveContext()

    let testLibrary = self.sut.getLibrary()
    XCTAssert(testLibrary.currentTheme.title == "theme-test")
  }

  func testCreateThemeFromParams() {
    let params: [String: Any] = [
      "title": "Default / Dark",
      "lightPrimaryHex": "242320",
      "lightSecondaryHex": "8F8E95",
      "lightAccentHex": "3488D1",
      "lightSeparatorHex": "DCDCDC",
      "lightSystemBackgroundHex": "FAFAFA",
      "lightSecondarySystemBackgroundHex": "FCFBFC",
      "lightTertiarySystemBackgroundHex": "E8E7E9",
      "lightSystemGroupedBackgroundHex": "EFEEF0",
      "lightSystemFillHex": "87A0BA",
      "lightSecondarySystemFillHex": "ACAAB1",
      "lightTertiarySystemFillHex": "3488D1",
      "lightQuaternarySystemFillHex": "3488D1",
      "darkPrimaryHex": "FAFBFC",
      "darkSecondaryHex": "8F8E94",
      "darkAccentHex": "459EEC",
      "darkSeparatorHex": "434448",
      "darkSystemBackgroundHex": "202225",
      "darkSecondarySystemBackgroundHex": "111113",
      "darkTertiarySystemBackgroundHex": "333538",
      "darkSystemGroupedBackgroundHex": "2C2D30",
      "darkSystemFillHex": "647E98",
      "darkSecondarySystemFillHex": "707176",
      "darkTertiarySystemFillHex": "459EEC",
      "darkQuaternarySystemFillHex": "459EEC",
      "locked": false
    ]

    let theme = self.sut.createTheme(params: params)
    XCTAssert(theme.title == "Default / Dark")
    XCTAssert(theme.lightPrimaryHex == "242320")
    XCTAssert(theme.darkPrimaryHex == "FAFBFC")
  }

  func testCreateBook() {
    let filename = "test-book.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Processed folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)
    let newBook = self.sut.createBook(from: fileUrl)
    XCTAssert(newBook.title == "test-book.txt")
    XCTAssert(newBook.relativePath == "/test-book.txt")
  }

  func testGetItemWithIdentifier() {
    let nilBook = self.sut.getItem(with: "test-book1")
    XCTAssert(nilBook == nil)

    let testBook = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    self.sut.dataManager.saveContext()

    let book = self.sut.getItem(with: testBook.relativePath)
    XCTAssert(testBook.relativePath == book?.relativePath)
  }

  func testFindEmptyBooksWithURL() {
    let books = self.sut.findBooks(containing: URL(string: "test/url")!)!
    XCTAssert(books.isEmpty)
  }

  func testFindBooksWithURL() {
    _ = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test1-book",
      duration: 100
    )

    _ = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test2-book",
      duration: 100
    )

    self.sut.dataManager.saveContext()

    let testURL = DataManager.getProcessedFolderURL().appendingPathComponent("-book.txt")

    let books = self.sut.findBooks(containing: testURL)!
    XCTAssert(books.count == 2)
  }

  func testFindEmptyOrderedBooks() {
    let books = self.sut.getOrderedBooks(limit: 20)!
    XCTAssert(books.isEmpty)
  }

  func testFindOrderedBooks() {
    let book1 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test1-book",
      duration: 100
    )
    book1.lastPlayDate = Date(timeIntervalSince1970: 1637636787)

    let book2 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test2-book",
      duration: 100
    )
    book2.lastPlayDate = Date()

    self.sut.dataManager.saveContext()

    let books = self.sut.getOrderedBooks(limit: 20)!
    XCTAssert(books.count == 2)
    let fetchedBook1 = books.first!
    XCTAssert(fetchedBook1.relativePath == book2.relativePath)
    let fetchedBook2 = books.last!
    XCTAssert(fetchedBook2.relativePath == book1.relativePath)
  }

  func testFindEmptyFolder() {
    let folder = self.sut.findFolder(with: URL(string: "test/url")!)
    XCTAssert(folder == nil)
  }

  func testFindFolder() {
    _ = try! StubFactory.folder(dataManager: self.sut.dataManager, title: "test1-folder")

    self.sut.dataManager.saveContext()

    let testURL = DataManager.getProcessedFolderURL().appendingPathComponent("test1-folder")

    let folder = self.sut.findFolder(with: testURL)
    XCTAssert(folder?.relativePath == "test1-folder")
  }

  func testHasNoLibraryLinked() {
    let book1 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test1-book",
      duration: 100
    )
    XCTAssert(self.sut.hasLibraryLinked(item: book1) == false)
  }

  func testHasLibraryLinked() {
    let library = self.sut.getLibrary()

    let book1 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test1-book",
      duration: 100
    )
    library.insert(item: book1)

    XCTAssert(self.sut.hasLibraryLinked(item: book1) == true)

    let folder1 = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test1-folder"
    )
    folder1.insert(item: book1)

    XCTAssert(self.sut.hasLibraryLinked(item: folder1) == false)
    XCTAssert(self.sut.hasLibraryLinked(item: book1) == false)

    library.insert(item: folder1)

    XCTAssert(self.sut.hasLibraryLinked(item: folder1) == true)
    XCTAssert(self.sut.hasLibraryLinked(item: book1) == true)

    let folder2 = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test2-folder",
      destinationFolder: DataManager.getProcessedFolderURL().appendingPathComponent(folder1.relativePath)
    )

    XCTAssert(self.sut.hasLibraryLinked(item: folder2) == false)

    folder1.insert(item: folder2)

    XCTAssert(self.sut.hasLibraryLinked(item: folder2) == true)
    XCTAssert(self.sut.hasLibraryLinked(item: book1) == true)
    XCTAssert(self.sut.hasLibraryLinked(item: folder1) == true)

    folder1.library = nil

    XCTAssert(self.sut.hasLibraryLinked(item: folder2) == false)
    XCTAssert(self.sut.hasLibraryLinked(item: book1) == false)
    XCTAssert(self.sut.hasLibraryLinked(item: folder1) == false)
  }

  func testNotRemovingFolderIfNeeded() {
    let library = self.sut.getLibrary()
    let folder1 = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test1-folder"
    )
    library.insert(item: folder1)

    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent("test1-folder")

    XCTAssert(FileManager.default.fileExists(atPath: fileURL.path))

    try! self.sut.removeFolderIfNeeded(
      DataManager.getProcessedFolderURL().appendingPathComponent("test1-folder")
    )

    XCTAssert(FileManager.default.fileExists(atPath: fileURL.path))
  }

  func testRemoveFolderIfNeeded() {
    _ = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test1-folder"
    )

    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent("test1-folder")

    XCTAssert(FileManager.default.fileExists(atPath: fileURL.path))

    try! self.sut.removeFolderIfNeeded(fileURL)

    XCTAssert(FileManager.default.fileExists(atPath: fileURL.path) == false)

    let library = self.sut.getLibrary()

    let book1 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test1-book",
      duration: 100
    )
    library.insert(item: book1)

    let folder2 = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test2-folder"
    )
    folder2.insert(item: book1)
    library.insert(item: folder2)

    let nestedURL = DataManager.getProcessedFolderURL().appendingPathComponent(folder2.relativePath)

    let folder3 = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test3-folder",
      destinationFolder: nestedURL
    )
    folder2.insert(item: folder3)

    XCTAssert(FileManager.default.fileExists(atPath: nestedURL.path))
    try! self.sut.removeFolderIfNeeded(nestedURL)
    XCTAssert(FileManager.default.fileExists(atPath: nestedURL.path))
    folder2.library = nil
    try! self.sut.removeFolderIfNeeded(nestedURL)
    XCTAssert(FileManager.default.fileExists(atPath: nestedURL.path) == false)
  }

  func testCreateFolderInLibrary() {
    let folder = try! self.sut.createFolder(with: "test-folder", inside: nil)

    let library = self.sut.getLibrary()

    XCTAssert(library.itemsArray.first?.relativePath == folder.relativePath)
    XCTAssert(folder.items?.count == 0)

    let folder2 = try! self.sut.createFolder(with: "test-folder2", inside: nil)

    XCTAssert(library.itemsArray.count == 2)
    XCTAssert(library.itemsArray.first?.relativePath == folder.relativePath)
    XCTAssert(library.itemsArray.last?.relativePath == folder2.relativePath)

    let folder3 = try! self.sut.createFolder(with: "test-folder3", inside: nil)

    XCTAssert(library.itemsArray.count == 3)
    XCTAssert(library.itemsArray[0].relativePath == folder.relativePath)
    XCTAssert(library.itemsArray[1].relativePath == folder2.relativePath)
    XCTAssert(library.itemsArray[2].relativePath == folder3.relativePath)
  }

  func testCreateFolderInFolder() {
    let folder = try! self.sut.createFolder(with: "test-folder", inside: nil)
    let folder2 = try! self.sut.createFolder(with: "test-folder2", inside: "test-folder")

    XCTAssert(folder.items?.count == 1)
    XCTAssert((folder.items?.firstObject as? Folder)?.relativePath == folder2.relativePath)

    let folder3 = try! self.sut.createFolder(with: "test-folder3", inside: "test-folder")

    XCTAssert(folder.items?.count == 2)
    XCTAssert((folder.items?.firstObject as? Folder)?.relativePath == folder2.relativePath)
    XCTAssert((folder.items?.lastObject as? Folder)?.relativePath == folder3.relativePath)

    let folder4 = try! self.sut.createFolder(with: "test-folder4", inside: "test-folder")

    XCTAssert(folder.items?.count == 3)
    XCTAssert((folder.items?[0] as? Folder)?.relativePath == folder2.relativePath)
    XCTAssert((folder.items?[1] as? Folder)?.relativePath == folder3.relativePath)
    XCTAssert((folder.items?[2] as? Folder)?.relativePath == folder4.relativePath)
  }

  func testFetchContents() {
    let folder = try! self.sut.createFolder(with: "test-folder", inside: nil)
    let folder2 = try! self.sut.createFolder(with: "test-folder2", inside: "test-folder")
    let folder3 = try! self.sut.createFolder(with: "test-folder3", inside: "test-folder")
    _ = try! self.sut.createFolder(with: "test-folder4", inside: "test-folder")

    let totalResults = self.sut.fetchContents(at: "test-folder", limit: nil, offset: nil)
    XCTAssert(totalResults?.count == 3)

    let partialResults1 = self.sut.fetchContents(at: "test-folder", limit: 1, offset: nil)
    XCTAssert(partialResults1?.count == 1)
    XCTAssert(partialResults1?[0].relativePath == folder2.relativePath)

    let partialResults2 = self.sut.fetchContents(at: "test-folder", limit: 1, offset: 1)
    XCTAssert(partialResults2?.count == 1)
    XCTAssert(partialResults2?[0].relativePath == folder3.relativePath)

    let folder5 = try! self.sut.createFolder(with: "test-folder5", inside: nil)
    _ = try! self.sut.createFolder(with: "test-folder6", inside: nil)

    let totalLibraryResults = self.sut.fetchContents(at: nil, limit: nil, offset: nil)
    XCTAssert(totalLibraryResults?.count == 3)

    let partialLibraryResults1 = self.sut.fetchContents(at: nil, limit: 1, offset: nil)
    XCTAssert(partialLibraryResults1?.count == 1)
    XCTAssert(partialLibraryResults1?[0].relativePath == folder.relativePath)

    let partialLibraryResults2 = self.sut.fetchContents(at: nil, limit: 1, offset: 1)
    XCTAssert(partialLibraryResults2?.count == 1)
    XCTAssert(partialLibraryResults2?[0].relativePath == folder5.relativePath)
  }

  func testMarkAsFinished() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    XCTAssert(book.isFinished == false)
    self.sut.markAsFinished(flag: true, relativePath: book.relativePath)
    XCTAssert(book.isFinished == true)

    let folder = try! self.sut.createFolder(with: "test-folder", inside: nil)

    let book2 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book2",
      duration: 100
    )
    book2.currentTime = 70

    let book3 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book3",
      duration: 100
    )
    book3.currentTime = 40

    folder.insert(item: book2)
    folder.insert(item: book3)

    XCTAssert(book2.isFinished == false)
    XCTAssert(book3.isFinished == false)
    self.sut.markAsFinished(flag: true, relativePath: folder.relativePath)
    XCTAssert(book2.isFinished == true)
    XCTAssert(book3.isFinished == true)
    self.sut.markAsFinished(flag: false, relativePath: folder.relativePath)
    XCTAssert(book2.isFinished == false)
    XCTAssert(book3.isFinished == false)
  }

  func testJumpToStart() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )
    book.currentTime = 50

    self.sut.jumpToStart(relativePath: book.relativePath)
    XCTAssert(book.currentTime == 0)

    let folder = try! self.sut.createFolder(with: "test-folder", inside: nil)

    let book2 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book2",
      duration: 100
    )
    book2.currentTime = 70

    let book3 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book3",
      duration: 100
    )
    book3.currentTime = 40

    folder.insert(item: book2)
    folder.insert(item: book3)

    self.sut.jumpToStart(relativePath: folder.relativePath)

    XCTAssert(book2.currentTime == 0)
    XCTAssert(book3.currentTime == 0)
  }

  func testRecordTime() {
    let record = self.sut.getCurrentPlaybackRecord()
    XCTAssert(record.time == 0)
    self.sut.recordTime(record)
    XCTAssert(record.time == 1)
  }

  func testGetCurrentPlaybackRecord() {
    let record = self.sut.getCurrentPlaybackRecord()
    self.sut.recordTime(record)
    XCTAssert(record.time == 1)
    let record2 = self.sut.getCurrentPlaybackRecord()
    XCTAssert(record2.time == 1)
  }

  // swiftlint:disable:next function_body_length
  func testGetPlaybackRecordsFromDate() {
    let calendar = Calendar.current
    let startToday = calendar.startOfDay(for: Date())
    let endDate = calendar.date(byAdding: .day, value: 1, to: startToday)!

    let startFirstDay = calendar.date(byAdding: .day, value: -7, to: endDate)!
    let startSecondDay = calendar.date(byAdding: .day, value: 1, to: startFirstDay)!
    let startThirdDay = calendar.date(byAdding: .day, value: 1, to: startSecondDay)!
    let startFourthDay = calendar.date(byAdding: .day, value: 1, to: startThirdDay)!
    let startFifthDay = calendar.date(byAdding: .day, value: 1, to: startFourthDay)!
    let startSixthDay = calendar.date(byAdding: .day, value: 1, to: startFifthDay)!
    let startSeventhDay = calendar.date(byAdding: .day, value: 1, to: startSixthDay)!

    let record1 = PlaybackRecord.create(in: self.sut.dataManager.getContext())
    record1.date = startFirstDay
    record1.time = 1
    let record2 = PlaybackRecord.create(in: self.sut.dataManager.getContext())
    record2.date = startSecondDay
    record2.time = 2
    let record3 = PlaybackRecord.create(in: self.sut.dataManager.getContext())
    record3.date = startThirdDay
    record3.time = 3
    let record4 = PlaybackRecord.create(in: self.sut.dataManager.getContext())
    record4.date = startFourthDay
    record4.time = 4
    let record5 = PlaybackRecord.create(in: self.sut.dataManager.getContext())
    record5.date = startFifthDay
    record5.time = 5
    let record6 = PlaybackRecord.create(in: self.sut.dataManager.getContext())
    record6.date = startSixthDay
    record6.time = 6
    let record7 = PlaybackRecord.create(in: self.sut.dataManager.getContext())
    record7.date = startSeventhDay
    record7.time = 7

    self.sut.dataManager.saveContext()

    let firstRecord = (self.sut.getPlaybackRecords(from: startFirstDay, to: startSecondDay) ?? []).first
    XCTAssert(firstRecord?.time == 1)
    let secondRecord = (self.sut.getPlaybackRecords(from: startSecondDay, to: startThirdDay) ?? []).first
    XCTAssert(secondRecord?.time == 2)
    let thirdRecord = (self.sut.getPlaybackRecords(from: startThirdDay, to: startFourthDay) ?? []).first
    XCTAssert(thirdRecord?.time == 3)
    let fourthRecord = (self.sut.getPlaybackRecords(from: startFourthDay, to: startFifthDay) ?? []).first
    XCTAssert(fourthRecord?.time == 4)
    let fifthRecord = (self.sut.getPlaybackRecords(from: startFifthDay, to: startSixthDay) ?? []).first
    XCTAssert(fifthRecord?.time == 5)
    let sixthRecord = (self.sut.getPlaybackRecords(from: startSixthDay, to: startSeventhDay) ?? []).first
    XCTAssert(sixthRecord?.time == 6)
    let seventhRecord = (self.sut.getPlaybackRecords(from: startSeventhDay, to: endDate) ?? []).first
    XCTAssert(seventhRecord?.time == 7)
  }

  func testCreateBookmark() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let bookmark = self.sut.createBookmark(at: 5, relativePath: book.relativePath, type: .skip)
    XCTAssert(bookmark.time == 5)
    XCTAssert(bookmark.type == .skip)
    XCTAssert(bookmark.item?.relativePath == book.relativePath)

    let sameBookmark = self.sut.createBookmark(at: 5, relativePath: book.relativePath, type: .skip)

    XCTAssert(bookmark.time == sameBookmark.time)
    XCTAssert(bookmark.type == sameBookmark.type)
    XCTAssert(bookmark.item?.relativePath == sameBookmark.item?.relativePath)
  }

  func testGetBookmarks() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    XCTAssert(self.sut.getBookmarks(of: .user, relativePath: book.relativePath)!.isEmpty)

    let bookmark = Bookmark.create(in: self.sut.dataManager.getContext())
    bookmark.type = .user
    book.addToBookmarks(bookmark)

    self.sut.dataManager.saveContext()

    XCTAssert(!self.sut.getBookmarks(of: .user, relativePath: book.relativePath)!.isEmpty)
  }

  func testGetBookmarkOfType() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    XCTAssert(self.sut.getBookmark(at: 10, relativePath: book.relativePath, type: .play) == nil)

    let bookmark = Bookmark.create(in: self.sut.dataManager.getContext())
    bookmark.type = .play
    bookmark.time = 10
    book.addToBookmarks(bookmark)

    XCTAssert(self.sut.getBookmark(at: 10, relativePath: book.relativePath, type: .play) != nil)
  }

  func testAddNote() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let bookmark = self.sut.createBookmark(at: 5, relativePath: book.relativePath, type: .skip)
    XCTAssert(bookmark.note == nil)
    self.sut.addNote("Test bookmark", bookmark: bookmark)
    XCTAssert(bookmark.note == "Test bookmark")
  }

  func testDeleteBookmark() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let bookmark = self.sut.createBookmark(at: 5, relativePath: book.relativePath, type: .skip)
    self.sut.deleteBookmark(bookmark)
    XCTAssert(bookmark.isFault)
  }

  func testRenameItem() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    self.sut.renameItem(at: book.relativePath, with: "rename-test")
    XCTAssert(book.title == "rename-test")
  }
}

// MARK: - insertBooks(from:into:or:completion:)

class InsertBooksTests: LibraryServiceTests {
  func testInsertEmptyBooksInLibrary() throws {

    let library = self.sut.getLibrary()

    try self.sut.moveItems([], inside: nil, moveFiles: true)

    XCTAssert(library.items?.count == 0)
  }

  func testInsertOneBookInLibrary() throws {
    let library = self.sut.getLibrary()

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Processed folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = self.sut.insertItems(from: [fileUrl], into: nil, library: library, processedItems: [])

    XCTAssert(library.items?.count == 1)
    XCTAssert(processedItems.count == 1)
  }

  func testInsertMultipleBooksInLibrary() throws {
    let library = self.sut.getLibrary()

    let filename1 = "file1.txt"
    let book1Contents = "book1contents".data(using: .utf8)!
    let filename2 = "file2.txt"
    let book2Contents = "book2contents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test files to Documents folder
    let file1Url = DataTestUtils.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: processedFolder)
    let file2Url = DataTestUtils.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: processedFolder)

    let processedItems = self.sut.insertItems(from: [file1Url, file2Url], into: nil, library: library, processedItems: [])

    XCTAssert(library.items?.count == 2)
    XCTAssert(processedItems.count == 2)
  }

  func testInsertEmptyBooksIntoPlaylist() throws {
    let library = self.sut.getLibrary()

    let folder = try self.sut.createFolder(with: "test-folder", inside: nil)
    XCTAssert(library.items?.count == 1)

    try? self.sut.moveItems([], inside: folder.relativePath, moveFiles: true)
    XCTAssert(folder.items?.count == 0)
  }

  func testInsertOneBookIntoPlaylist() throws {
    let library = self.sut.getLibrary()

    let folder = try self.sut.createFolder(with: "test-folder", inside: nil)

    XCTAssert(library.items?.count == 1)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = self.sut.insertItems(from: [fileUrl], into: folder, library: library, processedItems: [])
    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 1)
    XCTAssert(processedItems.count == 1)
  }

  func testInsertMultipleBooksIntoPlaylist() throws {
    let library = self.sut.getLibrary()

    let folder = try self.sut.createFolder(with: "test-folder", inside: nil)

    XCTAssert(library.items?.count == 1)

    let filename1 = "file1.txt"
    let book1Contents = "book1contents".data(using: .utf8)!
    let filename2 = "file2.txt"
    let book2Contents = "book2contents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test files to Documents folder
    let file1Url = DataTestUtils.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: processedFolder)
    let file2Url = DataTestUtils.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: processedFolder)

    let processedItems = self.sut.insertItems(from: [file1Url, file2Url], into: folder, library: library, processedItems: [])

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 2)
    XCTAssert(processedItems.count == 2)
  }

  func testInsertExistingBookFromLibraryIntoPlaylist() throws {
    let library = self.sut.getLibrary()

    let folder = try self.sut.createFolder(with: "test-folder", inside: nil)

    XCTAssert(library.items?.count == 1)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = self.sut.insertItems(from: [fileUrl], into: nil, library: library, processedItems: [])

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder.items?.count == 0)

    try self.sut.moveItems(processedItems, inside: folder.relativePath, moveFiles: true)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 1)
  }

  func testInsertExistingBookFromPlaylistIntoLibrary() throws {
    let library = self.sut.getLibrary()

    let folder = try self.sut.createFolder(with: "test-folder", inside: nil)

    XCTAssert(library.items?.count == 1)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = self.sut.insertItems(from: [fileUrl], into: nil, library: library, processedItems: [])

    try self.sut.moveItems(processedItems, inside: folder.relativePath, moveFiles: true)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 1)
    XCTAssert(processedItems.count == 1)

    try self.sut.moveItems(processedItems, inside: nil, moveFiles: true)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder.items?.count == 0)
  }

  func testInsertExistingBookFromPlaylistIntoPlaylist() throws {
    let library = self.sut.getLibrary()

    let folder1 = try self.sut.createFolder(with: "test-folder1", inside: nil)
    let folder2 = try self.sut.createFolder(with: "test-folder2", inside: nil)

    XCTAssert(library.items?.count == 2)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Processed folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = self.sut.insertItems(from: [fileUrl], into: nil, library: library, processedItems: [])

    try self.sut.moveItems(processedItems, inside: folder1.relativePath, moveFiles: true)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder1.items?.count == 1)
    XCTAssert(folder2.items?.count == 0)
    XCTAssert(processedItems.count == 1)

    try self.sut.moveItems(processedItems, inside: folder2.relativePath, moveFiles: true)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder1.items?.count == 0)
    XCTAssert(folder2.items?.count == 1)
  }
}

// MARK: - Modify Library

class ModifyLibraryTests: LibraryServiceTests {
  func testMoveItemsIntoFolder() throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    library.insert(item: book1)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    library.insert(item: book2)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    library.insert(item: folder)

    XCTAssert(library.items?.count == 3)

    try self.sut.moveItems([book1, book2], inside: folder.relativePath, moveFiles: true)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 2)

    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")
    library.insert(item: folder2)
    folder2.insert(item: book3)
    folder2.insert(item: book4)

    XCTAssert(library.items?.count == 2)

    try self.sut.moveItems([folder2], inside: folder.relativePath, moveFiles: true)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 3)
  }

  func testMoveItemsIntoLibrary() throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")

    try self.sut.moveItems([book1, book2, folder], inside: nil, moveFiles: true)
    try self.sut.moveItems([book1, book2], inside: folder.relativePath, moveFiles: true)

    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")

    try self.sut.moveItems([book3, book4, folder2], inside: nil, moveFiles: true)
    try self.sut.moveItems([folder, book3, book4], inside: folder2.relativePath, moveFiles: true)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder2.items?.count == 3)

    try self.sut.moveItems([folder], inside: nil, moveFiles: true)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder.items?.count == 2)

    try self.sut.moveItems([book3, book4], inside: nil, moveFiles: true)

    XCTAssert(library.items?.count == 4)
    XCTAssert(folder2.items?.count == 0)
  }

  func testFolderShallowDeleteWithOneBook() throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try self.sut.moveItems([book1], inside: folder.relativePath, moveFiles: true)
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")
    try self.sut.moveItems([folder], inside: folder2.relativePath, moveFiles: true)
    try self.sut.moveItems([folder2], inside: nil, moveFiles: true)

    try self.sut.delete([folder2], library: library, mode: .shallow)

    XCTAssert((library.items?.array as? [LibraryItem])?.first == folder)

    try self.sut.delete([folder], library: library, mode: .shallow)

    XCTAssert((library.items?.array as? [LibraryItem])?.first == book1)
  }

  func testFolderShallowDeleteWithMultipleBooks() throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    try self.sut.moveItems([book1], inside: nil, moveFiles: true)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try self.sut.moveItems([book2], inside: folder.relativePath, moveFiles: true)
    try self.sut.moveItems([book3], inside: folder.relativePath, moveFiles: true)
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")
    try self.sut.moveItems([folder], inside: folder2.relativePath, moveFiles: true)
    try self.sut.moveItems([book4], inside: folder2.relativePath, moveFiles: true)
    try self.sut.moveItems([folder2], inside: nil, moveFiles: true)

    try self.sut.delete([folder2], library: library, mode: .shallow)

    XCTAssert((library.items?.array as? [LibraryItem])?.first == book1)
    XCTAssert((library.items?.array as? [LibraryItem])?.last == book4)

    try self.sut.delete([folder], library: library, mode: .shallow)

    XCTAssert(library.items?.array is [Book])
    XCTAssert(library.items?.count == 4)
  }

  func testFolderDeepDeleteWithOneBook() throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")

    try self.sut.moveItems([book1, folder, folder2], inside: nil, moveFiles: true)
    try self.sut.moveItems([book1], inside: folder.relativePath, moveFiles: true)
    try self.sut.moveItems([folder], inside: folder2.relativePath, moveFiles: true)

    XCTAssert(folder2.items?.count == 1)

    try self.sut.delete([folder], library: library, mode: .deep)

    XCTAssert(folder2.items?.count == 0)
    XCTAssert(library.items?.count == 1)

    try self.sut.delete([folder2], library: library, mode: .deep)

    XCTAssert(library.items?.count == 0)
  }

  func testFolderDeepDeleteWithMultipleBooks() throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    library.insert(item: book1)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    library.insert(item: book2)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    library.insert(item: book3)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    library.insert(item: book4)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    library.insert(item: folder)
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")
    library.insert(item: folder2)

    try self.sut.moveItems([book2, book3], inside: folder.relativePath, moveFiles: true)
    try self.sut.moveItems([book4, folder], inside: folder2.relativePath, moveFiles: true)

    XCTAssert(folder2.items?.count == 2)

    try self.sut.delete([folder], library: library, mode: .deep)

    XCTAssert(folder2.items?.count == 1)
    XCTAssert(library.items?.count == 2)

    try self.sut.delete([folder2], library: library, mode: .deep)

    XCTAssert(library.items?.count == 1)
    XCTAssert((library.items?.array as? [LibraryItem])?.first == book1)
  }

  func testGetMaxItemsCount() throws {
    XCTAssert(self.sut.getMaxItemsCount(at: nil) == 0)
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    library.insert(item: book1)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    library.insert(item: book2)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    library.insert(item: book3)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    library.insert(item: book4)

    XCTAssert(self.sut.getMaxItemsCount(at: nil) == 4)

    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    library.insert(item: folder)
    try self.sut.moveItems([book1, book2, book3, book4], inside: folder.relativePath, moveFiles: true)

    XCTAssert(self.sut.getMaxItemsCount(at: nil) == 1)
    XCTAssert(self.sut.getMaxItemsCount(at: "folder") == 4)
  }

  func testReplaceOrderItems() throws {
    let library = self.sut.getLibrary()
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    library.insert(item: book4)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    library.insert(item: book3)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    library.insert(item: book2)
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    library.insert(item: book1)

    XCTAssert(library.itemsArray[0].title == book4.title)
    XCTAssert(library.itemsArray[3].title == book1.title)

    self.sut.replaceOrderedItems(NSOrderedSet(array: [book1, book2, book3, book4]), at: nil)

    XCTAssert(library.itemsArray[0].title == book1.title)
    XCTAssert(library.itemsArray[3].title == book4.title)

    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    library.insert(item: folder)
    try self.sut.moveItems([book1, book2, book3, book4], inside: folder.relativePath, moveFiles: true)

    XCTAssert((folder.items?.array[0] as? Book)?.title == book1.title)
    XCTAssert((folder.items?.array[3] as? Book)?.title == book4.title)

    self.sut.replaceOrderedItems(NSOrderedSet(array: [book4, book3, book2, book1]), at: folder.relativePath)

    XCTAssert((folder.items?.array[0] as? Book)?.title == book4.title)
    XCTAssert((folder.items?.array[3] as? Book)?.title == book1.title)
  }

  func testReorderItem() throws {
    let library = self.sut.getLibrary()
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    library.insert(item: book3)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    library.insert(item: book2)
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    library.insert(item: book1)

    XCTAssert(library.itemsArray[0].title == book3.title)
    XCTAssert(library.itemsArray[2].title == book1.title)

    self.sut.reorderItem(
      at: book3.relativePath,
      inside: nil,
      sourceIndexPath: IndexPath(row: 0, section: .data),
      destinationIndexPath: IndexPath(row: 2, section: .data)
    )

    XCTAssert(library.itemsArray[0].title == book2.title)
    XCTAssert(library.itemsArray[2].title == book3.title)

    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    library.insert(item: folder)
    try self.sut.moveItems([book1, book2, book3], inside: folder.relativePath, moveFiles: true)

    XCTAssert((folder.items?.array[0] as? Book)?.title == book1.title)
    XCTAssert((folder.items?.array[2] as? Book)?.title == book3.title)

    self.sut.reorderItem(
      at: book3.relativePath,
      inside: folder.relativePath,
      sourceIndexPath: IndexPath(row: 2, section: .data),
      destinationIndexPath: IndexPath(row: 0, section: .data)
    )

    XCTAssert((folder.items?.array[0] as? Book)?.title == book3.title)
    XCTAssert((folder.items?.array[2] as? Book)?.title == book2.title)
  }

  func testUpdateBookSpeed() throws {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try self.sut.moveItems([book], inside: folder.relativePath, moveFiles: true)

    self.sut.updateBookSpeed(at: book.relativePath, speed: 2.0)

    XCTAssert(book.speed == 2.0)
    XCTAssert(folder.speed == 2.0)
  }

  func testSetLibraryLastPlayedItem() {
    let library = self.sut.getLibrary()
    XCTAssert(library.lastPlayedItem == nil)

    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    self.sut.setLibraryLastBook(with: book.relativePath)

    XCTAssert(library.lastPlayedItem?.relativePath == book.relativePath)

    self.sut.setLibraryLastBook(with: nil)

    XCTAssert(library.lastPlayedItem == nil)
  }

  func testUpdateBookLastPlayDate() throws {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try self.sut.moveItems([book], inside: folder.relativePath, moveFiles: true)

    let now = Date()
    self.sut.updateBookLastPlayDate(at: book.relativePath, date: now)

    XCTAssert(book.lastPlayDate == now)
    XCTAssert(folder.lastPlayDate == now)
  }
}
