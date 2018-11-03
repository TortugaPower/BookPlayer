//
//  DataManagerTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 5/18/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

@testable import BookPlayer
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

        let destinationFolder = DataManager.getProcessedFolderURL()
        DataManager.processFile(at: fileUrl, destinationFolder: destinationFolder)

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

        let bookUrl = FileItem(originalUrl: fileUrl, processedUrl: fileUrl, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insertBooks(from: [bookUrl], into: library) {
            XCTAssert(library.items?.count == 1)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)
    }

    func testInsertSameBookInLibrary() {
        let library = DataManager.getLibrary()

        let filename = "file.txt"
        let bookContents = "bookcontents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        // Add test file to Documents folder
        let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)
        let bookUrl = FileItem(originalUrl: fileUrl, processedUrl: fileUrl, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insertBooks(from: [bookUrl], into: library) {
            XCTAssert(library.items?.count == 1)
            DataManager.insertBooks(from: [bookUrl], into: library) {
                XCTAssert(library.items?.count == 1)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 15)
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
        let book1Url = FileItem(originalUrl: file1Url, processedUrl: file1Url, destinationFolder: documentsFolder)
        let file2Url = DataTestUtils.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: documentsFolder)
        let book2Url = FileItem(originalUrl: file2Url, processedUrl: file2Url, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insertBooks(from: [book1Url, book2Url], into: library) {
            XCTAssert(library.items?.count == 2)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)
    }

    func testInsertEmptyBooksIntoPlaylist() {
        let library = DataManager.getLibrary()
        let playlist = DataManager.createPlaylist(title: "test-playlist", books: [])

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insert(playlist, into: library)
        XCTAssert(library.items?.count == 1)

        DataManager.insertBooks(from: [], into: playlist) {
            XCTAssert(playlist.books?.count == 0)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)
    }

    func testInsertOneBookIntoPlaylist() {
        let library = DataManager.getLibrary()
        let playlist = DataManager.createPlaylist(title: "test-playlist", books: [])

        let filename = "file.txt"
        let bookContents = "bookcontents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        // Add test file to Documents folder
        let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)
        let bookUrl = FileItem(originalUrl: fileUrl, processedUrl: fileUrl, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insert(playlist, into: library)
        XCTAssert(library.items?.count == 1)

        DataManager.insertBooks(from: [bookUrl], into: playlist) {
            XCTAssert(library.items?.count == 1)
            XCTAssert(playlist.books?.count == 1)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)
    }

    func testInsertMultipleBooksIntoPlaylist() {
        let library = DataManager.getLibrary()
        let playlist = DataManager.createPlaylist(title: "test-playlist", books: [])

        let filename1 = "file1.txt"
        let book1Contents = "book1contents".data(using: .utf8)!
        let filename2 = "file2.txt"
        let book2Contents = "book2contents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        // Add test files to Documents folder
        let file1Url = DataTestUtils.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: documentsFolder)
        let book1Url = FileItem(originalUrl: file1Url, processedUrl: file1Url, destinationFolder: documentsFolder)
        let file2Url = DataTestUtils.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: documentsFolder)
        let book2Url = FileItem(originalUrl: file2Url, processedUrl: file2Url, destinationFolder: documentsFolder)

        DataManager.insert(playlist, into: library)
        XCTAssert(library.items?.count == 1)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insertBooks(from: [book1Url, book2Url], into: playlist) {
            XCTAssert(library.items?.count == 1)
            XCTAssert(playlist.books?.count == 2)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)
    }

    func testInsertExistingBookFromLibraryIntoPlaylist() {
        let library = DataManager.getLibrary()
        let playlist = DataManager.createPlaylist(title: "test-playlist", books: [])

        let filename = "file.txt"
        let bookContents = "bookcontents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        // Add test file to Documents folder
        let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)
        let bookUrl = FileItem(originalUrl: fileUrl, processedUrl: fileUrl, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insert(playlist, into: library)
        XCTAssert(library.items?.count == 1)

        DataManager.insertBooks(from: [bookUrl], into: library) {
            XCTAssert(library.items?.count == 2)
            XCTAssert(playlist.books?.count == 0)

            DataManager.insertBooks(from: [bookUrl], into: playlist, completion: {
                XCTAssert(library.items?.count == 1)
                XCTAssert(playlist.books?.count == 1)

                expectation.fulfill()
            })
        }

        wait(for: [expectation], timeout: 15)
    }

    func testInsertExistingBookFromPlaylistIntoLibrary() {
        let library = DataManager.getLibrary()
        let playlist = DataManager.createPlaylist(title: "test-playlist", books: [])

        let filename = "file.txt"
        let bookContents = "bookcontents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        // Add test file to Documents folder
        let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)
        let bookUrl = FileItem(originalUrl: fileUrl, processedUrl: fileUrl, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insert(playlist, into: library)
        XCTAssert(library.items?.count == 1)

        DataManager.insertBooks(from: [bookUrl], into: playlist) {
            XCTAssert(library.items?.count == 1)
            XCTAssert(playlist.books?.count == 1)

            DataManager.insertBooks(from: [bookUrl], into: library, completion: {
                XCTAssert(library.items?.count == 2)
                XCTAssert(playlist.books?.count == 0)

                expectation.fulfill()
            })
        }

        wait(for: [expectation], timeout: 15)
    }

    func testInsertExistingBookFromPlaylistIntoPlaylist() {
        let library = DataManager.getLibrary()
        let playlist1 = DataManager.createPlaylist(title: "test-playlist1", books: [])
        let playlist2 = DataManager.createPlaylist(title: "test-playlist2", books: [])

        let filename = "file.txt"
        let bookContents = "bookcontents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        // Add test file to Documents folder
        let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)
        let bookUrl = FileItem(originalUrl: fileUrl, processedUrl: fileUrl, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insert(playlist1, into: library)
        DataManager.insert(playlist2, into: library)
        XCTAssert(library.items?.count == 2)

        DataManager.insertBooks(from: [bookUrl], into: playlist1) {
            XCTAssert(library.items?.count == 2)
            XCTAssert(playlist1.books?.count == 1)
            XCTAssert(playlist2.books?.count == 0)

            DataManager.insertBooks(from: [bookUrl], into: playlist2, completion: {
                XCTAssert(library.items?.count == 2)
                XCTAssert(playlist1.books?.count == 0)
                XCTAssert(playlist2.books?.count == 1)

                expectation.fulfill()
            })
        }

        wait(for: [expectation], timeout: 15)
    }
}
