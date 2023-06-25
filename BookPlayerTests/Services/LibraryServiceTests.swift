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
  // swiftlint:disable force_cast
  var sut: LibraryService!

  override func setUp() {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    self.sut = LibraryService(dataManager: dataManager)
    _ = self.sut.getLibrary()
  }

  func testGetExistingLibrary() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let newLibrary = self.sut.getLibrary()
    newLibrary.addToItems(book)

    let loadedLibrary = self.sut.getLibrary()
    XCTAssert(!loadedLibrary.itemsArray.isEmpty)
  }

  func testGetEmptyLibraryLastItem() {
    let lastBook = sut.getLibraryLastItem()
    XCTAssert(lastBook == nil)
  }

  func testGetLibraryLastBook() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let newLibrary = self.sut.getLibrary()
    XCTAssert(newLibrary.lastPlayedItem == nil)
    newLibrary.lastPlayedItem = book
    newLibrary.addToItems(book)

    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    let lastBook = sut.getLibraryLastItem()
    XCTAssert(lastBook?.relativePath == book.relativePath)
  }

  func testGetLibraryCurrentTheme() {
    XCTAssert(sut.getLibraryCurrentTheme() == nil)

    self.sut.setLibraryTheme(with: SimpleTheme.getDefaultTheme())

    let currentTheme = sut.getLibraryCurrentTheme()
    XCTAssert(currentTheme?.title == "Default / Dark")
  }

  func testCreateBook() async {
    let filename = "test-book.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Processed folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)
    let newBook = await self.sut.createBook(from: fileUrl)
    XCTAssert(newBook.title == "test-book.txt")
    XCTAssert(newBook.relativePath == "test-book.txt")
  }

  func testGetItemWithIdentifier() {
    let context = self.sut.dataManager.getContext()
    let nilBook = self.sut.getItem(with: "test-book1", context: context)
    XCTAssert(nilBook == nil)

    let testBook = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    self.sut.dataManager.saveContext(context)

    let book = self.sut.getItem(with: testBook.relativePath, context: context)
    XCTAssert(testBook.relativePath == book?.relativePath)
  }

  func testFindEmptyBooksWithURL() async {
    let books = await self.sut.findBooks(containing: URL(string: "test/url")!)!
    XCTAssert(books.isEmpty)
  }

  func testFindBooksWithURL() async {
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

    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    let testURL = DataManager.getProcessedFolderURL().appendingPathComponent("-book.txt")

    let books = await self.sut.findBooks(containing: testURL)!
    XCTAssert(books.count == 2)
  }

  func testFindEmptyOrderedBooks() async {
    let books = await self.sut.getLastPlayedItems(limit: 20)!
    XCTAssert(books.isEmpty)
  }

  func testFindOrderedBooks() async {
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

    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    let books = await self.sut.getLastPlayedItems(limit: 20)!
    XCTAssert(books.count == 2)
    let fetchedBook1 = books.first!
    XCTAssert(fetchedBook1.relativePath == book2.relativePath)
    let fetchedBook2 = books.last!
    XCTAssert(fetchedBook2.relativePath == book1.relativePath)
  }

  func testFindEmptyFolder() {
    let folder = self.sut.getItemReference(with: "test/url", context: self.sut.dataManager.getContext())
    XCTAssert(folder == nil)
  }

  func testFindFolder() {
    let context = self.sut.dataManager.getContext()
    _ = try! StubFactory.folder(dataManager: self.sut.dataManager, title: "test1-folder")

    self.sut.dataManager.saveContext(context)

    let folder = self.sut.getItemReference(with: "test1-folder", context: context)
    XCTAssert(folder?.relativePath == "test1-folder")
  }

  func testHasNoLibraryLinked() {
    let book1 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test1-book",
      duration: 100
    )
    XCTAssert(self.sut.hasLibraryLinked(item: book1, context: self.sut.dataManager.getContext()) == false)
  }

  func testHasLibraryLinked() async throws {
    let context = self.sut.dataManager.getContext()
    let library = self.sut.getLibrary()

    let book1 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test1-book",
      duration: 100
    )
    library.addToItems(book1)

    XCTAssert(self.sut.hasLibraryLinked(item: book1, context: context) == true)

    let folder1 = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test1-folder"
    )

    try await sut.moveItems([book1.relativePath], inside: folder1.relativePath)

    XCTAssert(self.sut.hasLibraryLinked(item: folder1, context: context) == false)
    XCTAssert(self.sut.hasLibraryLinked(item: book1, context: context) == false)

    try await sut.moveItems([folder1.relativePath], inside: nil)

    XCTAssert(self.sut.hasLibraryLinked(item: folder1, context: context) == true)
    XCTAssert(self.sut.hasLibraryLinked(item: book1, context: context) == true)

    let folder2 = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test2-folder",
      destinationFolder: DataManager.getProcessedFolderURL().appendingPathComponent(folder1.relativePath)
    )

    XCTAssert(self.sut.hasLibraryLinked(item: folder2, context: context) == false)

    try await sut.moveItems([folder2.relativePath], inside: folder1.relativePath)

    XCTAssert(self.sut.hasLibraryLinked(item: folder2, context: context) == true)
    XCTAssert(self.sut.hasLibraryLinked(item: book1, context: context) == true)
    XCTAssert(self.sut.hasLibraryLinked(item: folder1, context: context) == true)

    library.removeFromItems(folder1)
    self.sut.dataManager.saveContext(context)

    XCTAssert(self.sut.hasLibraryLinked(item: folder2, context: context) == false)
    XCTAssert(self.sut.hasLibraryLinked(item: book1, context: context) == false)
    XCTAssert(self.sut.hasLibraryLinked(item: folder1, context: context) == false)
  }

  func testNotRemovingFolderIfNeeded() {
    let library = self.sut.getLibrary()
    let folder1 = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test1-folder"
    )
    library.addToItems(folder1)

    let fileURL = DataManager.getProcessedFolderURL().appendingPathComponent("test1-folder")

    XCTAssert(FileManager.default.fileExists(atPath: fileURL.path))

    try! self.sut.removeFolderIfNeeded(
      DataManager.getProcessedFolderURL().appendingPathComponent("test1-folder"),
      context: self.sut.dataManager.getContext()
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

    try! self.sut.removeFolderIfNeeded(fileURL, context: self.sut.dataManager.getContext())

    XCTAssert(FileManager.default.fileExists(atPath: fileURL.path) == false)

    let library = self.sut.getLibrary()

    let book1 = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test1-book",
      duration: 100
    )
    library.addToItems(book1)

    let folder2 = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test2-folder"
    )
    folder2.addToItems(book1)
    library.addToItems(folder2)

    let nestedURL = DataManager.getProcessedFolderURL().appendingPathComponent(folder2.relativePath)

    let folder3 = try! StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test3-folder",
      destinationFolder: nestedURL
    )
    folder2.addToItems(folder3)

    XCTAssert(FileManager.default.fileExists(atPath: nestedURL.path))
    try! self.sut.removeFolderIfNeeded(nestedURL, context: self.sut.dataManager.getContext())
    XCTAssert(FileManager.default.fileExists(atPath: nestedURL.path))
    folder2.library = nil
    try! self.sut.removeFolderIfNeeded(nestedURL, context: self.sut.dataManager.getContext())
    XCTAssert(FileManager.default.fileExists(atPath: nestedURL.path) == false)
  }

  func testCreateFolderInLibrary() async {
    _ = try! await self.sut.createFolder(with: "test-folder", inside: nil)
    let folder = self.sut.getItem(with: "test-folder", context: self.sut.dataManager.getContext()) as! Folder

    let library = self.sut.getLibrary()

    XCTAssert(library.itemsArray.first?.relativePath == folder.relativePath)
    XCTAssert(folder.items?.count == 0)

    _ = try! await self.sut.createFolder(with: "test-folder2", inside: nil)
    let folder2 = self.sut.getItem(with: "test-folder2", context: self.sut.dataManager.getContext()) as! Folder

    XCTAssert(library.itemsArray.count == 2)
    XCTAssert(library.itemsArray.contains(where: { $0.relativePath == folder.relativePath}))
    XCTAssert(library.itemsArray.contains(where: { $0.relativePath == folder2.relativePath}))

    _ = try! await self.sut.createFolder(with: "test-folder3", inside: nil)
    let folder3 = self.sut.getItem(with: "test-folder3", context: self.sut.dataManager.getContext()) as! Folder

    XCTAssert(library.itemsArray.count == 3)
    XCTAssert(library.itemsArray.contains(where: { $0.relativePath == folder3.relativePath}))
  }

  func testCreateFolderInFolder() async {
    _ = try! await self.sut.createFolder(with: "test-folder", inside: nil)
    let folder = self.sut.getItem(with: "test-folder", context: self.sut.dataManager.getContext()) as! Folder
    _ = try! await self.sut.createFolder(with: "test-folder2", inside: "test-folder")
    let folder2 = self.sut.getItem(with: "test-folder/test-folder2", context: self.sut.dataManager.getContext()) as! Folder

    XCTAssert(folder.items?.count == 1)
    XCTAssert((folder.items?.allObjects.first as? Folder)?.relativePath == folder2.relativePath)

    _ = try! await self.sut.createFolder(with: "test-folder3", inside: "test-folder")
    let folder3 = self.sut.getItem(with: "test-folder/test-folder3", context: self.sut.dataManager.getContext()) as! Folder

    XCTAssert(folder.items?.count == 2)

    XCTAssert((folder.items?.allObjects as? [LibraryItem])?
      .contains(where: { $0.relativePath == folder3.relativePath}) ?? false)

    _ = try! await self.sut.createFolder(with: "test-folder4", inside: "test-folder")
    let folder4 = self.sut.getItem(with: "test-folder/test-folder4", context: self.sut.dataManager.getContext()) as! Folder

    XCTAssert(folder.items?.count == 3)
    XCTAssert((folder.items?.allObjects as? [LibraryItem])?
      .contains(where: { $0.relativePath == folder4.relativePath}) ?? false)
  }

  func testFetchContents() async {
    let folder = try! await self.sut.createFolder(with: "test-folder", inside: nil)
    let folder2 = try! await self.sut.createFolder(with: "test-folder2", inside: "test-folder")
    let folder3 = try! await self.sut.createFolder(with: "test-folder3", inside: "test-folder")
    _ = try! await self.sut.createFolder(with: "test-folder4", inside: "test-folder")

    let totalResults = self.sut.fetchContents(at: "test-folder", limit: nil, offset: nil)
    XCTAssert(totalResults?.count == 3)

    let partialResults1 = self.sut.fetchContents(at: "test-folder", limit: 1, offset: nil)
    XCTAssert(partialResults1?.count == 1)
    XCTAssert(partialResults1?[0].relativePath == folder2.relativePath)

    let partialResults2 = self.sut.fetchContents(at: "test-folder", limit: 1, offset: 1)
    XCTAssert(partialResults2?.count == 1)
    XCTAssert(partialResults2?[0].relativePath == folder3.relativePath)

    let folder5 = try! await self.sut.createFolder(with: "test-folder5", inside: nil)
    _ = try! await self.sut.createFolder(with: "test-folder6", inside: nil)

    let totalLibraryResults = self.sut.fetchContents(at: nil, limit: nil, offset: nil)
    XCTAssert(totalLibraryResults?.count == 3)

    let partialLibraryResults1 = self.sut.fetchContents(at: nil, limit: 1, offset: nil)
    XCTAssert(partialLibraryResults1?.count == 1)
    XCTAssert(partialLibraryResults1?[0].relativePath == folder.relativePath)

    let partialLibraryResults2 = self.sut.fetchContents(at: nil, limit: 1, offset: 1)
    XCTAssert(partialLibraryResults2?.count == 1)
    XCTAssert(partialLibraryResults2?[0].relativePath == folder5.relativePath)
  }

  func testMarkAsFinished() async {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    XCTAssert(book.isFinished == false)
    await self.sut.markAsFinished(flag: true, relativePath: book.relativePath)
    XCTAssert(book.isFinished == true)

    _ = try! await self.sut.createFolder(with: "test-folder", inside: nil)
    let folder = self.sut.getItem(with: "test-folder", context: self.sut.dataManager.getContext()) as! Folder

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

    folder.addToItems(book2)
    folder.addToItems(book3)

    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    XCTAssert(book2.isFinished == false)
    XCTAssert(book3.isFinished == false)
    await self.sut.markAsFinished(flag: true, relativePath: folder.relativePath)
    XCTAssert(book2.isFinished == true)
    XCTAssert(book3.isFinished == true)
    await self.sut.markAsFinished(flag: false, relativePath: folder.relativePath)
    XCTAssert(book2.isFinished == false)
    XCTAssert(book3.isFinished == false)
  }

  func testJumpToStart() async {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )
    book.currentTime = 50

    await self.sut.jumpToStart(relativePath: book.relativePath)
    XCTAssert(book.currentTime == 0)

    _ = try! await self.sut.createFolder(with: "test-folder", inside: nil)
    let folder = self.sut.getItem(with: "test-folder", context: self.sut.dataManager.getContext()) as! Folder

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

    folder.addToItems(book2)
    folder.addToItems(book3)

    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    await self.sut.jumpToStart(relativePath: folder.relativePath)

    XCTAssert(book2.currentTime == 0)
    XCTAssert(book3.currentTime == 0)
  }

  func testRecordTime() async {
    let initialTime = await self.sut.getCurrentPlaybackRecordTime()
    XCTAssert(initialTime == 0)
    self.sut.recordTime()
    let finalTime = await self.sut.getCurrentPlaybackRecordTime()
    XCTAssert(finalTime == 1)
  }

  func testGetCurrentPlaybackRecord() async {
    self.sut.recordTime()
    let time = await self.sut.getCurrentPlaybackRecordTime()
    XCTAssert(time == 1)
  }

  // swiftlint:disable:next function_body_length
  func testGetPlaybackRecordsFromDate() async {
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

    let context = self.sut.dataManager.getContext()
    self.sut.dataManager.saveContext(context)
    let firstRecordTime = await self.sut.getFirstPlaybackRecordTime(from: startFirstDay, to: startSecondDay)
    XCTAssert(firstRecordTime == 1)
    let secondRecordTime = await self.sut.getFirstPlaybackRecordTime(from: startSecondDay, to: startThirdDay)
    XCTAssert(secondRecordTime == 2)
    let thirdRecordTime = await self.sut.getFirstPlaybackRecordTime(from: startThirdDay, to: startFourthDay)
    XCTAssert(thirdRecordTime == 3)
    let fourthRecordTime = await self.sut.getFirstPlaybackRecordTime(from: startFourthDay, to: startFifthDay)
    XCTAssert(fourthRecordTime == 4)
    let fifthRecordTime = await self.sut.getFirstPlaybackRecordTime(from: startFifthDay, to: startSixthDay)
    XCTAssert(fifthRecordTime == 5)
    let sixthRecordTime = await self.sut.getFirstPlaybackRecordTime(from: startSixthDay, to: startSeventhDay)
    XCTAssert(sixthRecordTime == 6)
    let seventhRecordTime = await self.sut.getFirstPlaybackRecordTime(from: startSeventhDay, to: endDate)
    XCTAssert(seventhRecordTime == 7)
  }

  func testCreateBookmark() async {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let bookmark = await self.sut.createBookmark(at: 5, relativePath: book.relativePath, type: .skip)!
    XCTAssert(bookmark.time == 5)
    XCTAssert(bookmark.type == .skip)
    XCTAssert(bookmark.relativePath == book.relativePath)

    let sameBookmark = await self.sut.createBookmark(at: 5, relativePath: book.relativePath, type: .skip)!

    XCTAssert(bookmark.time == sameBookmark.time)
    XCTAssert(bookmark.type == sameBookmark.type)
    XCTAssert(bookmark.relativePath == sameBookmark.relativePath)
  }

  func testGetBookmarks() async {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let bookmarksEmpty = await self.sut.getBookmarks(of: .user, relativePath: book.relativePath)!
    XCTAssert(bookmarksEmpty.isEmpty)

    let bookmark = Bookmark.create(in: self.sut.dataManager.getContext())
    bookmark.type = .user
    book.addToBookmarks(bookmark)

    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    let bookmarksNotEmpty = await self.sut.getBookmarks(of: .user, relativePath: book.relativePath)!
    XCTAssert(!bookmarksNotEmpty.isEmpty)
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

    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    XCTAssert(self.sut.getBookmark(at: 10, relativePath: book.relativePath, type: .play) != nil)
  }

  func testAddNote() async {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let bookmark = await self.sut.createBookmark(at: 5, relativePath: book.relativePath, type: .skip)!
    XCTAssert(bookmark.note == nil)
    await self.sut.addNote("Test bookmark", bookmark: bookmark)
    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())
    let fetchedBookmark = self.sut.getBookmark(at: 5, relativePath: book.relativePath, type: .skip)!
    XCTAssert(fetchedBookmark.note == "Test bookmark")
  }

  func testDeleteBookmark() async {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let bookmark = await self.sut.createBookmark(at: 5, relativePath: book.relativePath, type: .skip)!
    await self.sut.deleteBookmark(bookmark)

    let fetchedBookmark = self.sut.getBookmark(at: 5, relativePath: book.relativePath, type: .skip)
    XCTAssert(fetchedBookmark == nil)
  }

  func testRenameBookItem() async {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    await sut.renameBook(at: book.relativePath, with: "rename-test")
    XCTAssert(book.title == "rename-test")
  }

  func testRenameFolderItem() async throws {
    let folder = try StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test-folder1"
    )
    let folder2 = try StubFactory.folder(
      dataManager: self.sut.dataManager,
      title: "test-folder2"
    )
    try await self.sut.moveItems([folder2.relativePath], inside: folder.relativePath)

    _ = try await self.sut.renameFolder(at: folder.relativePath, with: "rename-test")
    XCTAssert(folder.title == "rename-test")
    XCTAssert(folder.relativePath == "rename-test")
    XCTAssert(folder.originalFileName == "rename-test")
    XCTAssert(FileManager.default.fileExists(atPath: folder.fileURL!.path))

    let fetchedFolder2 = sut.getItem(with: "rename-test/test-folder2", context: self.sut.dataManager.getContext())!
    _ = try await self.sut.renameFolder(at: fetchedFolder2.relativePath, with: "rename-test2")
    XCTAssert(fetchedFolder2.title == "rename-test2")
    XCTAssert(fetchedFolder2.relativePath == "rename-test/rename-test2")
    XCTAssert(fetchedFolder2.originalFileName == "rename-test2")
    XCTAssert(FileManager.default.fileExists(atPath: fetchedFolder2.fileURL!.path))
  }
}

// MARK: - insertBooks(from:into:or:completion:)

class InsertBooksTests: LibraryServiceTests {
  func testInsertEmptyBooksInLibrary() async throws {

    let library = self.sut.getLibrary()

    try await self.sut.moveItems([], inside: nil)

    XCTAssert(library.items?.count == 0)
  }

  func testInsertOneBookInLibrary() async throws {
    let library = self.sut.getLibrary()

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Processed folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = await self.sut.insertItems(from: [fileUrl])

    XCTAssert(library.items?.count == 1)
    XCTAssert(processedItems.count == 1)
  }

  func testInsertMultipleBooksInLibrary() async throws {
    let library = self.sut.getLibrary()

    let filename1 = "file1.txt"
    let book1Contents = "book1contents".data(using: .utf8)!
    let filename2 = "file2.txt"
    let book2Contents = "book2contents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test files to Documents folder
    let file1Url = DataTestUtils.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: processedFolder)
    let file2Url = DataTestUtils.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: processedFolder)

    let processedItems = await self.sut.insertItems(from: [file1Url, file2Url])

    XCTAssert(library.items?.count == 2)
    XCTAssert(processedItems.count == 2)
  }

  func testInsertEmptyBooksIntoPlaylist() async throws {
    let library = self.sut.getLibrary()

    _ = try await self.sut.createFolder(with: "test-folder", inside: nil)
    let folder = self.sut.getItem(with: "test-folder", context: self.sut.dataManager.getContext()) as! Folder
    XCTAssert(library.items?.count == 1)

    try? await self.sut.moveItems([], inside: folder.relativePath)
    XCTAssert(folder.items?.count == 0)
  }

  func testInsertOneBookIntoPlaylist() async throws {
    let library = self.sut.getLibrary()

    _ = try await self.sut.createFolder(with: "test-folder", inside: nil)
    let folder = self.sut.getItem(with: "test-folder", context: self.sut.dataManager.getContext()) as! Folder

    XCTAssert(library.items?.count == 1)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = await sut.insertItems(from: [fileUrl])
      .map({ $0.relativePath })
    try await sut.moveItems(processedItems, inside: folder.relativePath)
    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 1)
    XCTAssert(processedItems.count == 1)
  }

  func testInsertMultipleBooksIntoPlaylist() async throws {
    let library = self.sut.getLibrary()

    _ = try await self.sut.createFolder(with: "test-folder", inside: nil)
    let folder = self.sut.getItem(with: "test-folder", context: self.sut.dataManager.getContext()) as! Folder

    XCTAssert(library.items?.count == 1)

    let filename1 = "file1.txt"
    let book1Contents = "book1contents".data(using: .utf8)!
    let filename2 = "file2.txt"
    let book2Contents = "book2contents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test files to Documents folder
    let file1Url = DataTestUtils.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: processedFolder)
    let file2Url = DataTestUtils.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: processedFolder)

    let processedItems = await sut.insertItems(from: [file1Url, file2Url])
      .map({ $0.relativePath })
    try await sut.moveItems(processedItems, inside: folder.relativePath)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 2)
    XCTAssert(processedItems.count == 2)
  }

  func testInsertExistingBookFromLibraryIntoPlaylist() async throws {
    let library = self.sut.getLibrary()

    _ = try await self.sut.createFolder(with: "test-folder", inside: nil)
    let folder = self.sut.getItem(with: "test-folder", context: self.sut.dataManager.getContext()) as! Folder

    XCTAssert(library.items?.count == 1)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = await self.sut.insertItems(from: [fileUrl])
      .map({ $0.relativePath })

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder.items?.count == 0)

    try await self.sut.moveItems(processedItems, inside: folder.relativePath)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 1)
  }

  func testInsertExistingBookFromPlaylistIntoLibrary() async throws {
    let library = self.sut.getLibrary()

    _ = try await self.sut.createFolder(with: "test-folder", inside: nil)
    let folder = self.sut.getItem(with: "test-folder", context: self.sut.dataManager.getContext()) as! Folder

    XCTAssert(library.items?.count == 1)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = await self.sut.insertItems(from: [fileUrl])
      .map({ $0.relativePath })

    try await self.sut.moveItems(processedItems, inside: folder.relativePath)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 1)
    XCTAssert(processedItems.count == 1)

    try await self.sut.moveItems(["test-folder/file.txt"], inside: nil)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder.items?.count == 0)
  }

  func testInsertExistingBookFromPlaylistIntoPlaylist() async throws {
    let library = self.sut.getLibrary()

    _ = try await self.sut.createFolder(with: "test-folder1", inside: nil)
    let folder1 = self.sut.getItem(with: "test-folder1", context: self.sut.dataManager.getContext()) as! Folder
    _ = try await self.sut.createFolder(with: "test-folder2", inside: nil)
    let folder2 = self.sut.getItem(with: "test-folder2", context: self.sut.dataManager.getContext()) as! Folder

    XCTAssert(library.items?.count == 2)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Processed folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = await self.sut.insertItems(from: [fileUrl])
      .map({ $0.relativePath })

    try await self.sut.moveItems(processedItems, inside: folder1.relativePath)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder1.items?.count == 1)
    XCTAssert(folder2.items?.count == 0)
    XCTAssert(processedItems.count == 1)

    try await self.sut.moveItems(["test-folder1/file.txt"], inside: folder2.relativePath)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder1.items?.count == 0)
    XCTAssert(folder2.items?.count == 1)
  }
}

// MARK: - Modify Library

class ModifyLibraryTests: LibraryServiceTests {
  func testMoveItemsIntoFolder() async throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    library.addToItems(book1)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    library.addToItems(book2)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    library.addToItems(folder)

    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    XCTAssert(library.items?.count == 3)

    try await self.sut.moveItems([book1.relativePath, book2.relativePath], inside: folder.relativePath)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 2)

    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")
    library.addToItems(folder2)
    folder2.addToItems(book3)
    folder2.addToItems(book4)

    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    XCTAssert(library.items?.count == 2)

    try await self.sut.moveItems([folder2.relativePath], inside: folder.relativePath)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 3)
  }

  func testMoveItemsIntoLibrary() async throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")

    try await self.sut.moveItems([book1.relativePath, book2.relativePath, folder.relativePath], inside: nil)
    try await self.sut.moveItems([book1.relativePath, book2.relativePath], inside: folder.relativePath)

    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")

    try await self.sut.moveItems([book3.relativePath, book4.relativePath, folder2.relativePath], inside: nil)
    try await self.sut.moveItems([folder.relativePath, book3.relativePath, book4.relativePath], inside: folder2.relativePath)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder2.items?.count == 3)

    try await self.sut.moveItems([folder.relativePath], inside: nil)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder.items?.count == 2)

    try await self.sut.moveItems([book3.relativePath, book4.relativePath], inside: nil)

    XCTAssert(library.items?.count == 4)
    XCTAssert(folder2.items?.count == 0)
  }

  func testFolderShallowDeleteWithOneBook() async throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try await self.sut.moveItems([book1.relativePath], inside: folder.relativePath)
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")
    try await self.sut.moveItems([folder.relativePath], inside: folder2.relativePath)
    try await self.sut.moveItems([folder2.relativePath], inside: nil)

    try await self.sut.delete([SimpleLibraryItem(from: folder2)], mode: .shallow)

    XCTAssert((library.items?.allObjects as? [LibraryItem])?.first == folder)

    try await self.sut.delete([SimpleLibraryItem(from: folder)], mode: .shallow)

    XCTAssert((library.items?.allObjects as? [LibraryItem])?.first == book1)
  }

  func testFolderShallowDeleteWithMultipleBooks() async throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    try await self.sut.moveItems([book1.relativePath], inside: nil)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try await self.sut.moveItems([book2.relativePath], inside: folder.relativePath)
    try await self.sut.moveItems([book3.relativePath], inside: folder.relativePath)
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")
    try await self.sut.moveItems([folder.relativePath], inside: folder2.relativePath)
    try await self.sut.moveItems([book4.relativePath], inside: folder2.relativePath)
    try await self.sut.moveItems([folder2.relativePath], inside: nil)

    try await self.sut.delete([SimpleLibraryItem(from: folder2)], mode: .shallow)

    XCTAssert(library.itemsArray
          .contains(where: { $0.relativePath == book1.relativePath}))
    XCTAssert(library.itemsArray
          .contains(where: { $0.relativePath == book4.relativePath}))

    try await self.sut.delete([SimpleLibraryItem(from: folder)], mode: .shallow)

    XCTAssert(library.items?.allObjects is [Book])
    XCTAssert(library.items?.count == 4)
  }

  func testFolderDeepDeleteWithOneBook() async throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")

    try await self.sut.moveItems([book1.relativePath, folder.relativePath, folder2.relativePath], inside: nil)
    try await self.sut.moveItems([book1.relativePath], inside: folder.relativePath)
    try await self.sut.moveItems([folder.relativePath], inside: folder2.relativePath)

    XCTAssert(folder2.items?.count == 1)

    try await self.sut.delete([SimpleLibraryItem(from: folder)], mode: .deep)

    XCTAssert(folder2.items?.count == 0)
    XCTAssert(library.items?.count == 1)

    try await self.sut.delete([SimpleLibraryItem(from: folder2)], mode: .deep)

    XCTAssert(library.items?.count == 0)
  }

  func testFolderDeepDeleteWithMultipleBooks() async throws {
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    library.addToItems(book1)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    library.addToItems(book2)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    library.addToItems(book3)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    library.addToItems(book4)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    library.addToItems(folder)
    let folder2 = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder2")
    library.addToItems(folder2)

    try await self.sut.moveItems([book2.relativePath, book3.relativePath], inside: folder.relativePath)
    try await self.sut.moveItems([book4.relativePath, folder.relativePath], inside: folder2.relativePath)

    XCTAssert(folder2.items?.count == 2)

    try await self.sut.delete([SimpleLibraryItem(from: folder)], mode: .deep)

    XCTAssert(folder2.items?.count == 1)
    XCTAssert(library.items?.count == 2)

    try await self.sut.delete([SimpleLibraryItem(from: folder2)], mode: .deep)

    XCTAssert(library.items?.count == 1)
    XCTAssert((library.items?.allObjects as? [LibraryItem])?.first == book1)
  }

  func testGetMaxItemsCount() async throws {
    XCTAssert(self.sut.getMaxItemsCount(at: nil) == 0)
    let library = self.sut.getLibrary()
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    library.addToItems(book1)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    library.addToItems(book2)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    library.addToItems(book3)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    library.addToItems(book4)

    XCTAssert(self.sut.getMaxItemsCount(at: nil) == 4)

    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    library.addToItems(folder)

    sut.dataManager.saveContext(self.sut.dataManager.getContext())

    try await self.sut.moveItems([book1.relativePath, book2.relativePath, book3.relativePath, book4.relativePath], inside: folder.relativePath)

    XCTAssert(self.sut.getMaxItemsCount(at: nil) == 1)
    XCTAssert(self.sut.getMaxItemsCount(at: "folder") == 4)
  }

  func testReplaceOrderItems() async throws {
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)

    try await sut.moveItems([book4.relativePath, book3.relativePath, book2.relativePath, book1.relativePath], inside: nil)

    let originalContents = sut.fetchContents(at: nil, limit: nil, offset: nil)

    XCTAssert(originalContents?[0].title == book4.title)
    XCTAssert(originalContents?[3].title == book1.title)

    await self.sut.sortContents(at: nil, by: .metadataTitle)

    let sortedContents = sut.fetchContents(at: nil, limit: nil, offset: nil)

    XCTAssert(sortedContents?[0].title == book1.title)
    XCTAssert(sortedContents?[3].title == book4.title)

    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try await sut.moveItems([folder.relativePath], inside: nil)
    try await self.sut.moveItems([book4.relativePath, book3.relativePath, book2.relativePath, book1.relativePath], inside: folder.relativePath)

    let folderContents = sut.fetchContents(at: folder.relativePath, limit: nil, offset: nil)
    XCTAssert(folderContents?[0].title == book4.title)
    XCTAssert(folderContents?[3].title == book1.title)

    await self.sut.sortContents(at: folder.relativePath, by: .metadataTitle)

    let sortedFolderContents = sut.fetchContents(at: folder.relativePath, limit: nil, offset: nil)
    XCTAssert(sortedFolderContents?[0].title == book1.title)
    XCTAssert(sortedFolderContents?[3].title == book4.title)
  }

  func testReorderItem() async throws {
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)

    try await sut.moveItems([book3.relativePath, book2.relativePath, book1.relativePath], inside: nil)

    let contents = sut.fetchContents(at: nil, limit: nil, offset: nil)
    XCTAssert(contents?[0].title == book3.title)
    XCTAssert(contents?[2].title == book1.title)

    await self.sut.reorderItem(
      with: book3.relativePath,
      inside: nil,
      sourceIndexPath: IndexPath(row: 0, section: .data),
      destinationIndexPath: IndexPath(row: 2, section: .data)
    )

    let sortedContents = sut.fetchContents(at: nil, limit: nil, offset: nil)

    XCTAssert(sortedContents?[0].title == book2.title)
    XCTAssert(sortedContents?[2].title == book3.title)

    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")

    try await sut.moveItems([folder.relativePath], inside: nil)
    try await self.sut.moveItems([book1.relativePath, book2.relativePath, book3.relativePath], inside: folder.relativePath)

    let folderContents = sut.fetchContents(at: folder.relativePath, limit: nil, offset: nil)
    XCTAssert(folderContents?[0].title == book1.title)
    XCTAssert(folderContents?[2].title == book3.title)

    await self.sut.reorderItem(
      with: book3.relativePath,
      inside: folder.relativePath,
      sourceIndexPath: IndexPath(row: 2, section: .data),
      destinationIndexPath: IndexPath(row: 0, section: .data)
    )

    let sortedFolderContents = sut.fetchContents(at: folder.relativePath, limit: nil, offset: nil)
    XCTAssert(sortedFolderContents?[0].title == book3.title)
    XCTAssert(sortedFolderContents?[2].title == book2.title)
  }

  func testUpdateBookSpeed() async throws {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try await self.sut.moveItems([book.relativePath], inside: folder.relativePath)

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

  func testUpdateBookLastPlayDate() async throws {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try await self.sut.moveItems([book.relativePath], inside: folder.relativePath)

    let now = Date()
    self.sut.updatePlaybackTime(
      relativePath: book.relativePath,
      time: 50,
      date: now,
      scheduleSave: false
    )

    XCTAssert(book.lastPlayDate == now)
    XCTAssert(book.currentTime == 50)
  }

  func testGetItemSpeed() async throws {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try await self.sut.moveItems([book.relativePath], inside: folder.relativePath)

    XCTAssert(book.speed == 1.0)
    XCTAssert(folder.speed == 1.0)

    let speed0 = self.sut.getItemSpeed(at: "")

    XCTAssert(speed0 == 1.0)

    let speed1 = self.sut.getItemSpeed(at: book.relativePath)

    XCTAssert(speed1 == 1.0)

    self.sut.updateBookSpeed(at: book.relativePath, speed: 3.0)

    let speed2 = self.sut.getItemSpeed(at: book.relativePath)

    XCTAssert(speed2 == 3.0)

    let speed3 = self.sut.getItemSpeed(at: folder.relativePath)

    XCTAssert(speed3 == 3.0)
  }

  func testGetChapters() async {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let chapters = [
      StubFactory.chapter(dataManager: self.sut.dataManager, index: 0),
      StubFactory.chapter(dataManager: self.sut.dataManager, index: 1),
      StubFactory.chapter(dataManager: self.sut.dataManager, index: 2)
    ]

    book.chapters = NSOrderedSet(array: chapters)
    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    let fetchedChapters = await self.sut.getChapters(from: book.relativePath)

    XCTAssert(fetchedChapters?.first?.index == 0)
    XCTAssert(fetchedChapters?[1].index == 1)
    XCTAssert(fetchedChapters?.last?.index == 2)
  }

  func testGetItemsNotIncluded() async throws {
    let emptyResult = await self.sut.getItemsToSync(remoteIdentifiers: [])
    XCTAssert(emptyResult?.isEmpty == true)

    _ = try! await self.sut.createFolder(with: "test-folder", inside: nil)
    _ = try! await self.sut.createFolder(with: "test-folder2", inside: nil)

    let secondResult = await self.sut.getItemsToSync(remoteIdentifiers: [])
    XCTAssert(secondResult?.count == 2)

    let thirdResult = await self.sut.getItemsToSync(remoteIdentifiers: ["test-folder"])
    XCTAssert(thirdResult?.count == 1)
  }

  func testGetItemProperty() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())
    let fetchedTitle = self.sut.getItemProperty("title", relativePath: book.relativePath) as? String
    XCTAssert(fetchedTitle == "test-book1")
    let fetchedDuration = self.sut.getItemProperty("duration", relativePath: book.relativePath) as? Double
    XCTAssert(fetchedDuration == 100)
    let fetchedIsFinished = self.sut.getItemProperty("isFinished", relativePath: book.relativePath) as? Bool
    XCTAssert(fetchedIsFinished == false)
  }

  func testFindItem() async throws {
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try await self.sut.moveItems([book1.relativePath, book2.relativePath, folder.relativePath], inside: nil)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    try await self.sut.moveItems([book3.relativePath, book4.relativePath], inside: folder.relativePath)

    book1.isFinished = true
    book3.isFinished = true
    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    let fetchedBook1 = await self.sut.findFirstItem(in: nil, isUnfinished: nil)
    let fetchedBook2 = await self.sut.findFirstItem(in: nil, isUnfinished: true)

    XCTAssert(fetchedBook1?.relativePath == book1.relativePath)
    XCTAssert(fetchedBook2?.relativePath == book2.relativePath)

    let fetchedBook3 = await self.sut.findFirstItem(in: folder.relativePath, isUnfinished: nil)
    let fetchedBook4 = await self.sut.findFirstItem(in: folder.relativePath, isUnfinished: true)

    XCTAssert(fetchedBook3?.relativePath == book3.relativePath)
    XCTAssert(fetchedBook4?.relativePath == book4.relativePath)
  }

  func testFindItemBeforeRank() async throws {
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try await self.sut.moveItems([book1.relativePath, book2.relativePath, folder.relativePath], inside: nil)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    try await self.sut.moveItems([book3.relativePath, book4.relativePath], inside: folder.relativePath)

    let fetchedBook1 = await self.sut.findFirstItem(in: nil, beforeRank: 1)

    XCTAssert(fetchedBook1?.relativePath == book1.relativePath)

    let fetchedBook2 = await self.sut.findFirstItem(in: folder.relativePath, beforeRank: 1)

    XCTAssert(fetchedBook2?.relativePath == book3.relativePath)
  }

  func testFindItemAfterRank() async throws {
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try await self.sut.moveItems([book1.relativePath, book2.relativePath, folder.relativePath], inside: nil)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    try await self.sut.moveItems([book3.relativePath, book4.relativePath], inside: folder.relativePath)

    book1.isFinished = true
    book3.isFinished = true
    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    let fetchedBook1 = await self.sut.findFirstItem(in: nil, afterRank: nil, isUnfinished: nil)
    let fetchedBook2 = await self.sut.findFirstItem(in: nil, afterRank: 0, isUnfinished: true)

    XCTAssert(fetchedBook1?.relativePath == book1.relativePath)
    XCTAssert(fetchedBook2?.relativePath == book2.relativePath)

    let fetchedBook3 = await self.sut.findFirstItem(in: folder.relativePath, afterRank: nil, isUnfinished: nil)
    let fetchedBook4 = await self.sut.findFirstItem(in: folder.relativePath, afterRank: 0, isUnfinished: true)

    XCTAssert(fetchedBook3?.relativePath == book3.relativePath)
    XCTAssert(fetchedBook4?.relativePath == book4.relativePath)
  }

  func testFilterBookItems() async throws {
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    try await self.sut.moveItems([book1.relativePath, book2.relativePath, folder.relativePath], inside: nil)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    try await self.sut.moveItems([book3.relativePath, book4.relativePath], inside: folder.relativePath)
    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    let fetchedNilBooks = await self.sut.filterContents(at: nil, query: "book21", scope: .book, limit: nil, offset: nil)

    XCTAssert(fetchedNilBooks?.count == 0)

    let fetchedAllBooks = await self.sut.filterContents(at: nil, query: "book", scope: .book, limit: nil, offset: nil)

    XCTAssert(fetchedAllBooks?.count == 4)

    let fetchedResults = await self.sut.filterContents(at: nil, query: "book1", scope: .book, limit: nil, offset: nil)

    XCTAssert(fetchedResults?.count == 1)
    XCTAssert(fetchedResults?.first?.relativePath == book1.relativePath)
  }

  func testFilterFolderItems() async throws {
    let now = Date().timeIntervalSince1970
    let book1 = StubFactory.book(dataManager: self.sut.dataManager, title: "book1", duration: 100)
    book1.lastPlayDate = Date(timeIntervalSince1970: now + 1)
    let book2 = StubFactory.book(dataManager: self.sut.dataManager, title: "book2", duration: 100)
    book2.lastPlayDate = Date(timeIntervalSince1970: now + 2)
    let folder = try StubFactory.folder(dataManager: self.sut.dataManager, title: "folder")
    folder.lastPlayDate = Date(timeIntervalSince1970: now + 3)
    try await self.sut.moveItems([book1.relativePath, book2.relativePath, folder.relativePath], inside: nil)
    let book3 = StubFactory.book(dataManager: self.sut.dataManager, title: "book3", duration: 100)
    book3.lastPlayDate = Date(timeIntervalSince1970: now + 4)
    let book4 = StubFactory.book(dataManager: self.sut.dataManager, title: "book4", duration: 100)
    book4.lastPlayDate = Date(timeIntervalSince1970: now + 5)
    try await self.sut.moveItems([book3.relativePath, book4.relativePath], inside: folder.relativePath)
    self.sut.dataManager.saveContext(self.sut.dataManager.getContext())

    let fetchedNilFolders = await self.sut.filterContents(at: nil, query: "folder2", scope: .folder, limit: nil, offset: nil)

    XCTAssert(fetchedNilFolders?.count == 0)

    let fetchedFolders = await self.sut.filterContents(at: nil, query: "folder", scope: .folder, limit: nil, offset: nil)

    XCTAssert(fetchedFolders?.count == 1)

    let fetchedResults = await self.sut.filterContents(
      at: folder.relativePath,
      query: nil,
      scope: .book,
      limit: nil,
      offset: nil
    )

    XCTAssert(fetchedResults?.count == 2)
    XCTAssert(fetchedResults?.first?.relativePath == book4.relativePath)
    XCTAssert(fetchedResults?.last?.relativePath == book3.relativePath)
  }
  // swiftlint:enable force_cast
}
