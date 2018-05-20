//
//  DataManagerTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 5/18/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import XCTest
@testable import BookPlayer

class DataManagerTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        let documentsFolder = DataManager.getDocumentsFolderURL()
        self.clearFolderContents(url: documentsFolder)
    }

    func generateTestFile(name: String, contents: Data, destinationFolder: URL) -> URL {
        let destination = destinationFolder.appendingPathComponent(name)

        XCTAssertNoThrow(try contents.write(to: destination))
        XCTAssert(FileManager.default.fileExists(atPath: destination.path))

        return destination
    }

    func clearFolderContents(url: URL) {
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            for url in urls {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print("Exception while clearing folder contents")
        }
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

        _ = self.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let urls = DataManager.getFiles(from: documentsFolder)!
        XCTAssert(urls.count == 1)
    }
}

// MARK: - processFiles()
class ProcessFilesTests: DataManagerTests {
    func testProcessFilesFromNilFolder() {
        let nonExistingFolder = URL(fileURLWithPath: "derp")
        DataManager.processFiles(in: nonExistingFolder) { (urls) in
            XCTAssert(urls.isEmpty)
        }
    }
    func testProcessNoFiles() {
        let documentsFolder = DataManager.getDocumentsFolderURL()

        DataManager.processFiles(in: documentsFolder) { (urls) in
            XCTAssert(urls.isEmpty)
        }
    }
    func testProcessPendingOneFile() {
        let filename = "file.txt"
        let bookContents = "bookcontents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()

        // Add test file to Documents folder
        let destination = self.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Processing pending files")

        DataManager.processFiles(in: documentsFolder) { (urls) in
            // Test file should no longer be in the Documents folder
            XCTAssert(!FileManager.default.fileExists(atPath: destination.path))

            let url = urls.first!

            // Name of processed file shouldn't be the same as the original
            XCTAssert(url.lastPathComponent != filename)

            let content = FileManager.default.contents(atPath: url.path)!
            XCTAssert(content == bookContents)

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)
    }

    func testProcessPendingMultipleFiles() {
        // Add test file to Documents folder
        let filename1 = "file1.txt"
        let book1Contents = "book1contents".data(using: .utf8)!
        let filename2 = "file2.txt"
        let book2Contents = "book2contents".data(using: .utf8)!
        let dataArray = [book1Contents, book2Contents]

        let documentsFolder = DataManager.getDocumentsFolderURL()

        let destination1 = self.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: documentsFolder)
        let destination2 = self.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Processing pending files")

        DataManager.processFiles(in: documentsFolder) { (urls) in
            // Test files should no longer be in the Documents folder
            XCTAssert(!FileManager.default.fileExists(atPath: destination1.path))
            XCTAssert(!FileManager.default.fileExists(atPath: destination2.path))

            // Count of returned urls should be the same as the number of test files generated
            XCTAssert(urls.count == 2)

            for url in urls {
                let content = FileManager.default.contents(atPath: url.path)!
                XCTAssertNotNil(dataArray.index(of: content))
            }

            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 15)
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
        let fileUrl = self.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insertBooks(from: [fileUrl], into: library) {

            XCTAssert(library.items?.count == 1)
            expectation.fulfill()
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
        let file1Url = self.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: documentsFolder)
        let file2Url = self.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insertBooks(from: [file1Url, file2Url], into: library) {

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
        let fileUrl = self.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insert(playlist, into: library)
        XCTAssert(library.items?.count == 1)

        DataManager.insertBooks(from: [fileUrl], into: playlist) {
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
        let file1Url = self.generateTestFile(name: filename1, contents: book1Contents, destinationFolder: documentsFolder)
        let file2Url = self.generateTestFile(name: filename2, contents: book2Contents, destinationFolder: documentsFolder)

        DataManager.insert(playlist, into: library)
        XCTAssert(library.items?.count == 1)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insertBooks(from: [file1Url, file2Url], into: playlist) {

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
        let fileUrl = self.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insert(playlist, into: library)
        XCTAssert(library.items?.count == 1)

        DataManager.insertBooks(from: [fileUrl], into: library) {
            XCTAssert(library.items?.count == 2)
            XCTAssert(playlist.books?.count == 0)

            DataManager.insertBooks(from: [fileUrl], into: playlist, completion: {
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
        let fileUrl = self.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insert(playlist, into: library)
        XCTAssert(library.items?.count == 1)

        DataManager.insertBooks(from: [fileUrl], into: playlist) {
            XCTAssert(library.items?.count == 1)
            XCTAssert(playlist.books?.count == 1)

            DataManager.insertBooks(from: [fileUrl], into: library, completion: {
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
        let fileUrl = self.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let expectation = XCTestExpectation(description: "Insert books into library")

        DataManager.insert(playlist1, into: library)
        DataManager.insert(playlist2, into: library)
        XCTAssert(library.items?.count == 2)

        DataManager.insertBooks(from: [fileUrl], into: playlist1) {
            XCTAssert(library.items?.count == 2)
            XCTAssert(playlist1.books?.count == 1)
            XCTAssert(playlist2.books?.count == 0)

            DataManager.insertBooks(from: [fileUrl], into: playlist2, completion: {
                XCTAssert(library.items?.count == 2)
                XCTAssert(playlist1.books?.count == 0)
                XCTAssert(playlist2.books?.count == 1)

                expectation.fulfill()
            })
        }

        wait(for: [expectation], timeout: 15)
    }
}
