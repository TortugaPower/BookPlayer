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
}
