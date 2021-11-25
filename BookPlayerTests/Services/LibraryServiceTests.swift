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

  func testGetEmptyLibraryLastBook() {
    let lastBook = try! self.sut.getLibraryLastBook()
    XCTAssert(lastBook == nil)
  }

  func testGetLibraryLastBook() {
    let book = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    let newLibrary = self.sut.createLibrary()
    XCTAssert(newLibrary.lastPlayedBook == nil)
    newLibrary.lastPlayedBook = book
    newLibrary.insert(item: book)

    self.sut.dataManager.saveContext()

    let lastBook = try! self.sut.getLibraryLastBook()
    XCTAssert(lastBook?.relativePath == book.relativePath)
  }

  func testGetEmptyLibraryCurrentTheme() {
    let currentTheme = try! self.sut.getLibraryCurrentTheme()
    XCTAssert(currentTheme == nil)
  }

  func testGetLibraryCurrentTheme() {
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
    let folder = try! self.sut.createFolder(with: "test-folder", inside: nil, at: nil)

    let library = self.sut.getLibrary()

    XCTAssert(library.itemsArray.first?.relativePath == folder.relativePath)
    XCTAssert(folder.items?.count == 0)

    let folder2 = try! self.sut.createFolder(with: "test-folder2", inside: nil, at: nil)

    XCTAssert(library.itemsArray.count == 2)
    XCTAssert(library.itemsArray.first?.relativePath == folder.relativePath)
    XCTAssert(library.itemsArray.last?.relativePath == folder2.relativePath)

    let folder3 = try! self.sut.createFolder(with: "test-folder3", inside: nil, at: 0)

    XCTAssert(library.itemsArray.count == 3)
    XCTAssert(library.itemsArray[0].relativePath == folder3.relativePath)
    XCTAssert(library.itemsArray[1].relativePath == folder.relativePath)
    XCTAssert(library.itemsArray[2].relativePath == folder2.relativePath)

    let folder4 = try! self.sut.createFolder(with: "test-folder4", inside: nil, at: 1)

    XCTAssert(library.itemsArray.count == 4)
    XCTAssert(library.itemsArray[0].relativePath == folder3.relativePath)
    XCTAssert(library.itemsArray[1].relativePath == folder4.relativePath)
    XCTAssert(library.itemsArray[2].relativePath == folder.relativePath)
    XCTAssert(library.itemsArray[3].relativePath == folder2.relativePath)
  }

  func testCreateFolderInFolder() {
    let folder = try! self.sut.createFolder(with: "test-folder", inside: nil, at: nil)
    let folder2 = try! self.sut.createFolder(with: "test-folder2", inside: "test-folder", at: nil)

    XCTAssert(folder.items?.count == 1)
    XCTAssert((folder.items?.firstObject as? Folder)?.relativePath == folder2.relativePath)

    let folder3 = try! self.sut.createFolder(with: "test-folder3", inside: "test-folder", at: nil)

    XCTAssert(folder.items?.count == 2)
    XCTAssert((folder.items?.firstObject as? Folder)?.relativePath == folder2.relativePath)
    XCTAssert((folder.items?.lastObject as? Folder)?.relativePath == folder3.relativePath)

    let folder4 = try! self.sut.createFolder(with: "test-folder4", inside: "test-folder", at: 0)

    XCTAssert(folder.items?.count == 3)
    XCTAssert((folder.items?[0] as? Folder)?.relativePath == folder4.relativePath)
    XCTAssert((folder.items?[1] as? Folder)?.relativePath == folder2.relativePath)
    XCTAssert((folder.items?[2] as? Folder)?.relativePath == folder3.relativePath)

    let folder5 = try! self.sut.createFolder(with: "test-folder5", inside: "test-folder", at: 1)

    XCTAssert(folder.items?.count == 4)
    XCTAssert((folder.items?[0] as? Folder)?.relativePath == folder4.relativePath)
    XCTAssert((folder.items?[1] as? Folder)?.relativePath == folder5.relativePath)
    XCTAssert((folder.items?[2] as? Folder)?.relativePath == folder2.relativePath)
    XCTAssert((folder.items?[3] as? Folder)?.relativePath == folder3.relativePath)
  }

  func testFetchContents() {
    let folder = try! self.sut.createFolder(with: "test-folder", inside: nil, at: nil)
    let folder2 = try! self.sut.createFolder(with: "test-folder2", inside: "test-folder", at: nil)
    let folder3 = try! self.sut.createFolder(with: "test-folder3", inside: "test-folder", at: nil)
    _ = try! self.sut.createFolder(with: "test-folder4", inside: "test-folder", at: nil)

    let totalResults = self.sut.fetchContents(at: "test-folder", limit: nil, offset: nil)
    XCTAssert(totalResults?.count == 3)

    let partialResults1 = self.sut.fetchContents(at: "test-folder", limit: 1, offset: nil)
    XCTAssert(partialResults1?.count == 1)
    XCTAssert(partialResults1?[0].relativePath == folder2.relativePath)

    let partialResults2 = self.sut.fetchContents(at: "test-folder", limit: 1, offset: 1)
    XCTAssert(partialResults2?.count == 1)
    XCTAssert(partialResults2?[0].relativePath == folder3.relativePath)

    let folder5 = try! self.sut.createFolder(with: "test-folder5", inside: nil, at: nil)
    _ = try! self.sut.createFolder(with: "test-folder6", inside: nil, at: nil)

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

    let folder = try! self.sut.createFolder(with: "test-folder", inside: nil, at: nil)

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

    let folder = try! self.sut.createFolder(with: "test-folder", inside: nil, at: nil)

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
}
