//
//  DataManagerTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 5/18/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class DataManagerTests: XCTestCase {
  var dataManager: DataManager!

  override func setUp() {
    super.setUp()
    self.dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    // Put setup code here. This method is called before the invocation of each test method in the class.
    let documentsFolder = DataManager.getDocumentsFolderURL()
    DataTestUtils.clearFolderContents(url: documentsFolder)
    let processedFolder = DataManager.getProcessedFolderURL()
    DataTestUtils.clearFolderContents(url: processedFolder)
  }
}

// MARK: - processFiles()

class ProcessFilesTests: DataManagerTests {
  var importManager: ImportManager!
  var subscription: AnyCancellable?

  override func setUp() {
    self.subscription?.cancel()
    super.setUp()
  }

  func testProcessOneFile() {
    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let documentsFolder = DataManager.getDocumentsFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

    let expectation = XCTestExpectation(description: "File import notification")

    self.importManager = ImportManager(dataManager: self.dataManager)

    self.subscription = self.importManager.observeFiles().sink { files in
      guard !files.isEmpty else { return }

      expectation.fulfill()
    }

    self.importManager.process(fileUrl)

    wait(for: [expectation], timeout: 15)
  }
}

// MARK: - insertBooks(from:into:or:completion:)

class InsertBooksTests: DataManagerTests {
  func testInsertEmptyBooksInLibrary() throws {

    let library = StubFactory.library(dataManager: self.dataManager)

    try self.dataManager.moveItems([], into: library)

    XCTAssert(library.items?.count == 0)
  }

  func testInsertOneBookInLibrary() throws {
    let library = StubFactory.library(dataManager: self.dataManager)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Processed folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = self.dataManager.insertItems(from: [fileUrl], into: nil, library: library)

    XCTAssert(library.items?.count == 1)
    XCTAssert(processedItems.count == 1)
  }

  func testInsertMultipleBooksInLibrary() throws {
    let library = StubFactory.library(dataManager: self.dataManager)

    let filename1 = "file1.txt"
    let book1Contents = "book1contents".data(using: .utf8)!
    let filename2 = "file2.txt"
    let book2Contents = "book2contents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test files to Documents folder
    let file1Url = DataTestUtils.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: processedFolder)
    let file2Url = DataTestUtils.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: processedFolder)

    let processedItems = self.dataManager.insertItems(from: [file1Url, file2Url], into: nil, library: library)

    XCTAssert(library.items?.count == 2)
    XCTAssert(processedItems.count == 2)
  }

  func testInsertEmptyBooksIntoPlaylist() throws {
    let libraryService = LibraryService(dataManager: self.dataManager)
    let library = libraryService.getLibrary()

    let folder = try libraryService.createFolder(with: "test-folder", inside: nil, at: nil)
    XCTAssert(library.items?.count == 1)

    try? self.dataManager.moveItems([], into: folder)
    XCTAssert(folder.items?.count == 0)
  }

  func testInsertOneBookIntoPlaylist() throws {
    let libraryService = LibraryService(dataManager: self.dataManager)
    let library = libraryService.getLibrary()

    let folder = try libraryService.createFolder(with: "test-folder", inside: nil, at: nil)

    XCTAssert(library.items?.count == 1)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = self.dataManager.insertItems(from: [fileUrl], into: folder, library: library)
    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 1)
    XCTAssert(processedItems.count == 1)
  }

  func testInsertMultipleBooksIntoPlaylist() throws {
    let libraryService = LibraryService(dataManager: self.dataManager)
    let library = libraryService.getLibrary()

    let folder = try libraryService.createFolder(with: "test-folder", inside: nil, at: nil)

    XCTAssert(library.items?.count == 1)

    let filename1 = "file1.txt"
    let book1Contents = "book1contents".data(using: .utf8)!
    let filename2 = "file2.txt"
    let book2Contents = "book2contents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test files to Documents folder
    let file1Url = DataTestUtils.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: processedFolder)
    let file2Url = DataTestUtils.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: processedFolder)

    let processedItems = self.dataManager.insertItems(from: [file1Url, file2Url], into: folder, library: library)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 2)
    XCTAssert(processedItems.count == 2)
  }

  func testInsertExistingBookFromLibraryIntoPlaylist() throws {
    let libraryService = LibraryService(dataManager: self.dataManager)
    let library = libraryService.getLibrary()

    let folder = try libraryService.createFolder(with: "test-folder", inside: nil, at: nil)

    XCTAssert(library.items?.count == 1)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = self.dataManager.insertItems(from: [fileUrl], into: nil, library: library)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder.items?.count == 0)

    try self.dataManager.moveItems(processedItems, into: folder)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 1)
  }

  func testInsertExistingBookFromPlaylistIntoLibrary() throws {
    let libraryService = LibraryService(dataManager: self.dataManager)
    let library = libraryService.getLibrary()

    let folder = try libraryService.createFolder(with: "test-folder", inside: nil, at: nil)

    XCTAssert(library.items?.count == 1)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = self.dataManager.insertItems(from: [fileUrl], into: nil, library: library)

    try self.dataManager.moveItems(processedItems, into: folder)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 1)
    XCTAssert(processedItems.count == 1)

    try self.dataManager.moveItems(processedItems, into: library)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder.items?.count == 0)
  }

  func testInsertExistingBookFromPlaylistIntoPlaylist() throws {
    let libraryService = LibraryService(dataManager: self.dataManager)
    let library = libraryService.getLibrary()

    let folder1 = try libraryService.createFolder(with: "test-folder1", inside: nil, at: nil)
    let folder2 = try libraryService.createFolder(with: "test-folder2", inside: nil, at: nil)

    XCTAssert(library.items?.count == 2)

    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let processedFolder = DataManager.getProcessedFolderURL()

    // Add test file to Processed folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: processedFolder)

    let processedItems = self.dataManager.insertItems(from: [fileUrl], into: nil, library: library)

    try self.dataManager.moveItems(processedItems, into: folder1)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder1.items?.count == 1)
    XCTAssert(folder2.items?.count == 0)
    XCTAssert(processedItems.count == 1)

    try self.dataManager.moveItems(processedItems, into: folder2)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder1.items?.count == 0)
    XCTAssert(folder2.items?.count == 1)
  }
}

// MARK: - Modify Library

class ModifyLibraryTests: DataManagerTests {
  func testMoveItemsIntoFolder() throws {
    let library = StubFactory.library(dataManager: self.dataManager)
    let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
    library.insert(item: book1)
    let book2 = StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
    library.insert(item: book2)
    let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")
    library.insert(item: folder)

    XCTAssert(library.items?.count == 3)

    try self.dataManager.moveItems([book1, book2], into: folder)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 2)

    let book3 = StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.dataManager, title: "book4", duration: 100)
    let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")
    library.insert(item: folder2)
    folder2.insert(item: book3)
    folder2.insert(item: book4)

    XCTAssert(library.items?.count == 2)

    try self.dataManager.moveItems([folder2], into: folder)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder.items?.count == 3)
  }

  func testMoveItemsIntoLibrary() throws {
    let library = StubFactory.library(dataManager: self.dataManager)
    let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
    let book2 = StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")

    try self.dataManager.moveItems([book1, book2, folder], into: library)
    try self.dataManager.moveItems([book1, book2], into: folder)

    let book3 = StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.dataManager, title: "book4", duration: 100)
    let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")

    try self.dataManager.moveItems([book3, book4, folder2], into: library)
    try self.dataManager.moveItems([folder, book3, book4], into: folder2)
    //        library.insert(item: folder2)

    XCTAssert(library.items?.count == 1)
    XCTAssert(folder2.items?.count == 3)

    try self.dataManager.moveItems([folder], into: library)

    XCTAssert(library.items?.count == 2)
    XCTAssert(folder.items?.count == 2)

    try self.dataManager.moveItems([book3, book4], into: library)

    XCTAssert(library.items?.count == 4)
    XCTAssert(folder2.items?.count == 0)
  }

  func testFolderShallowDeleteWithOneBook() throws {
    let library = StubFactory.library(dataManager: self.dataManager)
    let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")
    try self.dataManager.moveItems([book1], into: folder)
    let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")
    try self.dataManager.moveItems([folder], into: folder2)
    try self.dataManager.moveItems([folder2], into: library)

    try self.dataManager.delete([folder2], library: library, mode: .shallow)

    XCTAssert((library.items?.array as? [LibraryItem])?.first == folder)

    try self.dataManager.delete([folder], library: library, mode: .shallow)

    XCTAssert((library.items?.array as? [LibraryItem])?.first == book1)
  }

  func testFolderShallowDeleteWithMultipleBooks() throws {
    let library = StubFactory.library(dataManager: self.dataManager)
    let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
    try self.dataManager.moveItems([book1], into: library)
    let book2 = StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
    let book3 = StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)
    let book4 = StubFactory.book(dataManager: self.dataManager, title: "book4", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")
    try self.dataManager.moveItems([book2], into: folder)
    try self.dataManager.moveItems([book3], into: folder)
    let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")
    try self.dataManager.moveItems([folder], into: folder2)
    try self.dataManager.moveItems([book4], into: folder2)
    try self.dataManager.moveItems([folder2], into: library)

    try self.dataManager.delete([folder2], library: library, mode: .shallow)

    XCTAssert((library.items?.array as? [LibraryItem])?.first == book1)
    XCTAssert((library.items?.array as? [LibraryItem])?.last == book4)

    try self.dataManager.delete([folder], library: library, mode: .shallow)

    XCTAssert(library.items?.array is [Book])
    XCTAssert(library.items?.count == 4)
  }

  func testFolderDeepDeleteWithOneBook() throws {
    let library = StubFactory.library(dataManager: self.dataManager)
    let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
    let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")
    let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")

    try self.dataManager.moveItems([book1, folder, folder2], into: library)
    try self.dataManager.moveItems([book1], into: folder)
    try self.dataManager.moveItems([folder], into: folder2)

    XCTAssert(folder2.items?.count == 1)

    try self.dataManager.delete([folder], library: library, mode: .deep)

    XCTAssert(folder2.items?.count == 0)
    XCTAssert(library.items?.count == 1)

    try self.dataManager.delete([folder2], library: library, mode: .deep)

    XCTAssert(library.items?.count == 0)
  }

  func testFolderDeepDeleteWithMultipleBooks() throws {
    let library = StubFactory.library(dataManager: self.dataManager)
    let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
    library.insert(item: book1)
    let book2 = StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
    library.insert(item: book2)
    let book3 = StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)
    library.insert(item: book3)
    let book4 = StubFactory.book(dataManager: self.dataManager, title: "book4", duration: 100)
    library.insert(item: book4)
    let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")
    library.insert(item: folder)
    let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")
    library.insert(item: folder2)

    try self.dataManager.moveItems([book2, book3], into: folder)
    try self.dataManager.moveItems([book4, folder], into: folder2)

    XCTAssert(folder2.items?.count == 2)

    try self.dataManager.delete([folder], library: library, mode: .deep)

    XCTAssert(folder2.items?.count == 1)
    XCTAssert(library.items?.count == 2)

    try self.dataManager.delete([folder2], library: library, mode: .deep)

    XCTAssert(library.items?.count == 1)
    XCTAssert((library.items?.array as? [LibraryItem])?.first == book1)
  }
}
