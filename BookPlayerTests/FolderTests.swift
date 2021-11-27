//
//  PlaylistTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 6/19/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class FolderTests: XCTestCase {
  var dataManager: DataManager!

    override func setUp() {
      super.setUp()

      self.dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
      let documentsFolder = DataManager.getDocumentsFolderURL()
      DataTestUtils.clearFolderContents(url: documentsFolder)
      let processedFolder = DataManager.getProcessedFolderURL()
      DataTestUtils.clearFolderContents(url: processedFolder)
    }

    func testGetNilBook() throws {
        let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")

        let fetchedBookByIdentifier = folder.getItem(with: "book1")

        XCTAssertNil(fetchedBookByIdentifier)
    }

    func testGetBook() throws {
        let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)

        let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")
        folder.insert(item: book1)

        let fetchedBookByIdentifier = folder.getItem(with: book1.relativePath)

        XCTAssertNotNil(fetchedBookByIdentifier)
    }

    func testGetNestedBook() throws {
        let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
        let book2 = StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)

        let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")
        folder.insert(item: book1)
        let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")
        folder2.insert(item: folder)
        folder2.insert(item: book2)

        let fetchedBookByIdentifier = folder2.getItem(with: book2.relativePath)

        XCTAssertNotNil(fetchedBookByIdentifier)
    }

    func testAccumulatedProgress() throws {
        let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
        let book2 = StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
        let book3 = StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)

        let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")
        folder.insert(item: book1)
        folder.insert(item: book2)
        let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")
        folder2.insert(item: folder)
        folder2.insert(item: book3)

        let emptyProgress = folder.progressPercentage
        let nestedEmptyProgress = folder2.progressPercentage

        XCTAssert(emptyProgress == 0.0)
        XCTAssert(nestedEmptyProgress == 0.0)

        book1.setCurrentTime(50)
        book2.setCurrentTime(50)
        book3.setCurrentTime(20)

        let halfProgress = folder.progressPercentage
        let nestedPartProgress = folder2.progressPercentage

        XCTAssert(halfProgress == 0.5)
        XCTAssert(nestedPartProgress == 0.4)

        book1.setCurrentTime(100)
        book2.setCurrentTime(100)
        book3.setCurrentTime(100)

        let completedProgress = folder.progressPercentage
        let nestedCompletedProgress = folder2.progressPercentage

        XCTAssert(completedProgress == 1.0)
        XCTAssert(nestedCompletedProgress == 1.0)
    }

    func testNextBookFromPlayer() throws {
        let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
        let book2 = StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
        let book3 = StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)

        let folder = try StubFactory.folder(dataManager: self.dataManager, title: "playlist")
        folder.insert(item: book1)
        folder.insert(item: book2)
        let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")
        folder2.insert(item: folder)
        folder2.insert(item: book3)

        let nextBook = folder.getNextBook(after: book1)
        let nextBook2 = folder2.getNextBook(after: book2)

        XCTAssert(nextBook == book2)
        XCTAssert(nextBook2 == book3)
    }

    func testNextBookFromArtwork() throws {
        let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
        book1.setCurrentTime(100)
        book1.isFinished = true
        let book2 = StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
        let book3 = StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)

        let folder = try StubFactory.folder(dataManager: self.dataManager, title: "playlist")
        folder.insert(item: book1)
        folder.insert(item: book2)
        let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")
        folder2.insert(item: folder)
        folder2.insert(item: book3)

        let nextBook = folder.getBookToPlay()
        let nestedNextBook = folder2.getBookToPlay()

        XCTAssert(nextBook == book2)
        XCTAssert(nestedNextBook == book2)
    }

    func testRelativePath() throws {
        let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
        let book2 = StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
        let book3 = StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)

        let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")
        folder.insert(item: book1)
        folder.insert(item: book2)
        let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")
        folder2.insert(item: folder)
        folder2.insert(item: book3)

        XCTAssert(folder.relativePath == "folder2/folder")
        XCTAssert(folder2.relativePath == "folder2")
        XCTAssert(book1.relativePath == "folder2/folder/book1.txt")
        XCTAssert(book2.relativePath == "folder2/folder/book2.txt")
        XCTAssert(book3.relativePath == "folder2/book3.txt")
    }
}
