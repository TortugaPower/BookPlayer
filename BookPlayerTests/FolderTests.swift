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
    override func setUp() {
        super.setUp()
    }

    func generateFolder(title: String, items: [LibraryItem]) -> Folder {
        return DataManager.createFolder(title: title, items: items)
    }

    func testGetNilBook() {
        let folder = self.generateFolder(title: "folder", items: [])

        let fetchedBookByIdentifier = folder.getItem(with: "book1")

        XCTAssertNil(fetchedBookByIdentifier)
    }

    func testGetBook() {
        let book1 = StubFactory.book(title: "book1", duration: 100)

        let folder = self.generateFolder(title: "folder", items: [book1])

        let fetchedBookByIdentifier = folder.getItem(with: "book1")

        XCTAssertNotNil(fetchedBookByIdentifier)
    }

    func testAccumulatedProgress() {
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let book2 = StubFactory.book(title: "book2", duration: 100)
        let book3 = StubFactory.book(title: "book3", duration: 100)

        let folder = self.generateFolder(title: "folder", items: [book1, book2])
        let folder2 = self.generateFolder(title: "folder2", items: [folder, book3])

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

    func testNextBookFromPlayer() {
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let book2 = StubFactory.book(title: "book2", duration: 100)
        let book3 = StubFactory.book(title: "book3", duration: 100)

        let folder = self.generateFolder(title: "playlist", items: [book1, book2])
        let folder2 = self.generateFolder(title: "folder2", items: [folder, book3])

        let nextBook = folder.getNextBook(after: book1)
        let nextBook2 = folder2.getNextBook(after: book2)

        XCTAssert(nextBook == book2)
        XCTAssert(nextBook2 == book3)
    }

    func testNextBookFromArtwork() {
        let book1 = StubFactory.book(title: "book1", duration: 100)
        book1.setCurrentTime(100)
        book1.isFinished = true
        let book2 = StubFactory.book(title: "book2", duration: 100)
        let book3 = StubFactory.book(title: "book3", duration: 100)

        let folder = self.generateFolder(title: "playlist", items: [book1, book2])
        let folder2 = self.generateFolder(title: "folder2", items: [folder, book3])

        let nextBook = folder.getBookToPlay()
        let nestedNextBook = folder2.getBookToPlay()

        XCTAssert(nextBook == book2)
        XCTAssert(nestedNextBook == book2)
    }
}
