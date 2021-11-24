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

  func testGetEmptyBookWithIdentifier() {
    let book = self.sut.getBook(with: "test-book1")
    XCTAssert(book == nil)
  }

  func testGetBookWithIdentifier() {
    let testBook = StubFactory.book(
      dataManager: self.sut.dataManager,
      title: "test-book1",
      duration: 100
    )

    self.sut.dataManager.saveContext()

    let book = self.sut.getBook(with: testBook.relativePath)
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
}
