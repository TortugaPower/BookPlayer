//
//  DataManagerTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 5/18/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class DataManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let documentsFolder = DataManager.getDocumentsFolderURL()
        DataTestUtils.clearFolderContents(url: documentsFolder)
    }
}

// MARK: - getFiles()

class GetFilesTests: DataManagerTests {
    func testGetFilesFromNilFolder() {
        let nonExistingFolder = URL(fileURLWithPath: "derp")
        XCTAssertNil(DataManager.getFiles(from: nonExistingFolder))
    }

    func testGetFiles() {
        let filename = "file.txt"
        let bookContents = "bookcontents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        _ = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let urls = DataManager.getFiles(from: documentsFolder)!
        XCTAssert(urls.count == 1)
    }
}

// MARK: - processFiles()

class ProcessFilesTests: DataManagerTests {
    func testProcessOneFile() {
        let filename = "file.txt"
        let bookContents = "bookcontents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        // Add test file to Documents folder
        let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let promiseNewUrl = expectation(forNotification: .newFileUrl, object: nil)
        let promiseOperation = expectation(forNotification: .importOperation, object: nil)

        DataManager.processFile(at: fileUrl)

        wait(for: [promiseNewUrl, promiseOperation], timeout: 15)
    }
}

// MARK: - insertBooks(from:into:or:completion:)

class InsertBooksTests: DataManagerTests {
    override func setUp() {
        super.setUp()

        let library = DataManager.getLibrary()
        DataManager.delete(library)
    }

    func testInsertEmptyBooksInLibrary() {
        let library = DataManager.getLibrary()

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insertBooks(from: [], into: library) {
            XCTAssert(library.items?.count == 0)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)
    }

    func testInsertOneBookInLibrary() {
        let library = DataManager.getLibrary()

        let filename = "file.txt"
        let bookContents = "bookcontents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        // Add test file to Documents folder
        let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let processedItems = DataManager.insertItems(from: [fileUrl], into: nil, library: library)

        XCTAssert(library.items?.count == 1)
        XCTAssert(processedItems.count == 1)
    }

    func testInsertMultipleBooksInLibrary() {
        let library = DataManager.getLibrary()

        let filename1 = "file1.txt"
        let book1Contents = "book1contents".data(using: .utf8)!
        let filename2 = "file2.txt"
        let book2Contents = "book2contents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        // Add test files to Documents folder
        let file1Url = DataTestUtils.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: documentsFolder)
        let file2Url = DataTestUtils.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: documentsFolder)

        let processedItems = DataManager.insertItems(from: [file1Url, file2Url], into: nil, library: library)

        XCTAssert(library.items?.count == 2)
        XCTAssert(processedItems.count == 2)
    }

    func testInsertEmptyBooksIntoPlaylist() throws {
      let library = DataManager.getLibrary()
      let folder = try XCTUnwrap(try DataManager.createFolder(with: "test-folder", in: nil, library: library))
      XCTAssert(library.items?.count == 1)

      try? DataManager.moveItems([], into: folder)
      XCTAssert(folder.items?.count == 0)
    }

    func testInsertOneBookIntoPlaylist() throws {
      let library = DataManager.getLibrary()
      let folder = try DataManager.createFolder(with: "test-folder", in: nil, library: library)

      XCTAssert(library.items?.count == 1)

      let filename = "file.txt"
      let bookContents = "bookcontents".data(using: .utf8)!
      let documentsFolder = DataManager.getDocumentsFolderURL()

      // Add test file to Documents folder
      let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

      let processedItems = DataManager.insertItems(from: [fileUrl], into: folder, library: library)
      XCTAssert(library.items?.count == 1)
      XCTAssert(folder.items?.count == 1)
      XCTAssert(processedItems.count == 1)
    }

    func testInsertMultipleBooksIntoPlaylist() throws {
      let library = DataManager.getLibrary()
      let folder = try DataManager.createFolder(with: "test-folder", in: nil, library: library)

      XCTAssert(library.items?.count == 1)

      let filename1 = "file1.txt"
      let book1Contents = "book1contents".data(using: .utf8)!
      let filename2 = "file2.txt"
      let book2Contents = "book2contents".data(using: .utf8)!
      let documentsFolder = DataManager.getDocumentsFolderURL()

      // Add test files to Documents folder
      let file1Url = DataTestUtils.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: documentsFolder)
      let file2Url = DataTestUtils.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: documentsFolder)

      let processedItems = DataManager.insertItems(from: [file1Url, file2Url], into: folder, library: library)

      XCTAssert(library.items?.count == 1)
      XCTAssert(folder.items?.count == 2)
      XCTAssert(processedItems.count == 2)
    }

    func testInsertExistingBookFromLibraryIntoPlaylist() throws {
      let library = DataManager.getLibrary()
      let folder = try DataManager.createFolder(with: "test-folder", in: nil, library: library)

      XCTAssert(library.items?.count == 1)

      let filename = "file.txt"
      let bookContents = "bookcontents".data(using: .utf8)!
      let documentsFolder = DataManager.getDocumentsFolderURL()

      // Add test file to Documents folder
      let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

      let processedItems = DataManager.insertItems(from: [fileUrl], into: nil, library: library)

      XCTAssert(library.items?.count == 2)
      XCTAssert(folder.items?.count == 0)

      try DataManager.moveItems(processedItems, into: folder)

      XCTAssert(library.items?.count == 1)
      XCTAssert(folder.items?.count == 1)
    }

    func testInsertExistingBookFromPlaylistIntoLibrary() throws {
      let library = DataManager.getLibrary()
      let folder = try DataManager.createFolder(with: "test-folder", in: nil, library: library)

      XCTAssert(library.items?.count == 1)

      let filename = "file.txt"
      let bookContents = "bookcontents".data(using: .utf8)!
      let documentsFolder = DataManager.getDocumentsFolderURL()

      // Add test file to Documents folder
      let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

      let processedItems = DataManager.insertItems(from: [fileUrl], into: folder, library: library)
      XCTAssert(library.items?.count == 1)
      XCTAssert(folder.items?.count == 1)
      XCTAssert(processedItems.count == 1)

      try DataManager.moveItems(processedItems, into: library)

      XCTAssert(library.items?.count == 2)
      XCTAssert(folder.items?.count == 0)
    }

    func testInsertExistingBookFromPlaylistIntoPlaylist() throws {
      let library = DataManager.getLibrary()
      let folder1 = try DataManager.createFolder(with: "test-folder1", in: nil, library: library)
      let folder2 = try DataManager.createFolder(with: "test-folder2", in: nil, library: library)

      XCTAssert(library.items?.count == 2)

      let filename = "file.txt"
      let bookContents = "bookcontents".data(using: .utf8)!
      let documentsFolder = DataManager.getDocumentsFolderURL()

      // Add test file to Documents folder
      let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

      let processedItems = DataManager.insertItems(from: [fileUrl], into: folder1, library: library)

      XCTAssert(library.items?.count == 2)
      XCTAssert(folder1.items?.count == 1)
      XCTAssert(folder2.items?.count == 0)
      XCTAssert(processedItems.count == 1)

      try DataManager.moveItems(processedItems, into: folder2)

      XCTAssert(library.items?.count == 2)
      XCTAssert(folder1.items?.count == 0)
      XCTAssert(folder2.items?.count == 1)
    }
}

// MARK: - Modify Library

class ModifyLibraryTests: DataManagerTests {
    override func setUp() {
        super.setUp()

        let library = DataManager.getLibrary()
        DataManager.delete(library)
    }

    func testMoveItemsIntoFolder() {
        let library = DataManager.getLibrary()
        let book1 = StubFactory.book(title: "book1", duration: 100)
        library.insert(item: book1)
        let book2 = StubFactory.book(title: "book2", duration: 100)
        library.insert(item: book2)
        let folder = StubFactory.folder(title: "folder", items: [])
        library.insert(item: folder)

        XCTAssert(library.items?.count == 3)

        try? DataManager.moveItems([book1, book2], into: folder)

        XCTAssert(library.items?.count == 1)
        XCTAssert(folder.items?.count == 2)

        let book3 = StubFactory.book(title: "book3", duration: 100)
        let book4 = StubFactory.book(title: "book4", duration: 100)
        let folder2 = StubFactory.folder(title: "folder2", items: [book3, book4])
        library.insert(item: folder2)

        XCTAssert(library.items?.count == 2)

        try? DataManager.moveItems([folder2], into: folder)

        XCTAssert(library.items?.count == 1)
        XCTAssert(folder.items?.count == 3)
    }

    func testMoveItemsIntoLibrary() {
        let library = DataManager.getLibrary()
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let book2 = StubFactory.book(title: "book2", duration: 100)
        let folder = StubFactory.folder(title: "folder", items: [book1, book2])

        let book3 = StubFactory.book(title: "book3", duration: 100)
        let book4 = StubFactory.book(title: "book4", duration: 100)
        let folder2 = StubFactory.folder(title: "folder2", items: [folder, book3, book4])
        library.insert(item: folder2)

        XCTAssert(library.items?.count == 1)
        XCTAssert(folder2.items?.count == 3)

        try? DataManager.moveItems([folder], into: library)

        XCTAssert(library.items?.count == 2)
        XCTAssert(folder.items?.count == 2)

        try? DataManager.moveItems([book3, book4], into: library)

        XCTAssert(library.items?.count == 4)
        XCTAssert(folder2.items?.count == 0)
    }

    func testFolderShallowDeleteWithOneBook() {
        let library = DataManager.getLibrary()
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let folder = StubFactory.folder(title: "folder", items: [book1])
        let folder2 = StubFactory.folder(title: "folder2", items: [folder])
        library.insert(item: folder2)

        try? DataManager.delete([folder2], library: library, mode: .shallow)

        XCTAssert((library.items?.array as? [LibraryItem])?.first == folder)

        try? DataManager.delete([folder], library: library, mode: .shallow)

        XCTAssert((library.items?.array as? [LibraryItem])?.first == book1)
    }

    func testFolderShallowDeleteWithMultipleBooks() {
        let library = DataManager.getLibrary()
        let book1 = StubFactory.book(title: "book1", duration: 100)
        library.insert(item: book1)
        let book2 = StubFactory.book(title: "book2", duration: 100)
        let book3 = StubFactory.book(title: "book3", duration: 100)
        let book4 = StubFactory.book(title: "book4", duration: 100)
        let folder = StubFactory.folder(title: "folder", items: [book2, book3])
        let folder2 = StubFactory.folder(title: "folder2", items: [folder, book4])
        library.insert(item: folder2)

        try? DataManager.delete([folder2], library: library, mode: .shallow)

        XCTAssert((library.items?.array as? [LibraryItem])?.first == book1)
        XCTAssert((library.items?.array as? [LibraryItem])?.last == book4)

        try? DataManager.delete([folder], library: library, mode: .shallow)

        XCTAssert(library.items?.array is [Book])
        XCTAssert(library.items?.count == 4)
    }

    func testFolderDeepDeleteWithOneBook() {
        let library = DataManager.getLibrary()
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let folder = StubFactory.folder(title: "folder", items: [book1])
        let folder2 = StubFactory.folder(title: "folder2", items: [folder])
        library.insert(item: folder2)

        XCTAssert(folder2.items?.count == 1)

        try? DataManager.delete([folder], library: library, mode: .deep)

        XCTAssert(folder2.items?.count == 0)
        XCTAssert(library.items?.count == 1)

        try? DataManager.delete([folder2], library: library, mode: .deep)

        XCTAssert(library.items?.count == 0)
    }

    func testFolderDeepDeleteWithMultipleBooks() {
        let library = DataManager.getLibrary()
        let book1 = StubFactory.book(title: "book1", duration: 100)
        library.insert(item: book1)
        let book2 = StubFactory.book(title: "book2", duration: 100)
        let book3 = StubFactory.book(title: "book3", duration: 100)
        let book4 = StubFactory.book(title: "book4", duration: 100)
        let folder = StubFactory.folder(title: "folder", items: [book2, book3])
        let folder2 = StubFactory.folder(title: "folder2", items: [folder, book4])
        library.insert(item: folder2)

        XCTAssert(folder2.items?.count == 2)

        try? DataManager.delete([folder], library: library, mode: .deep)

        XCTAssert(folder2.items?.count == 1)
        XCTAssert(library.items?.count == 2)

        try? DataManager.delete([folder2], library: library, mode: .deep)

        XCTAssert(library.items?.count == 1)
        XCTAssert((library.items?.array as? [LibraryItem])?.first == book1)
    }
}
