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

class PlaylistTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func generateFolder(title: String, books: [Book]) -> Folder {
        return DataManager.createFolder(title: title, books: books)
    }

    func testGetNilBook() {
        let folder = self.generateFolder(title: "folder", books: [])

        let fetchedBookByIdentifier = folder.getBook(with: "book1")

        XCTAssertNil(fetchedBookByIdentifier)

        let dummyUrl = URL(fileURLWithPath: "book1")
        let fetchedBookByUrl = folder.getBook(with: dummyUrl)

        XCTAssertNil(fetchedBookByUrl)
    }

    func testGetBook() {
        let book1 = StubFactory.book(title: "book1", duration: 100)

        let folder = self.generateFolder(title: "folder", books: [book1])

        let fetchedBookByIdentifier = folder.getBook(with: "book1")

        XCTAssertNotNil(fetchedBookByIdentifier)

        let dummyUrl = URL(fileURLWithPath: "book1")
        let fetchedBookByUrl = folder.getBook(with: dummyUrl)

        XCTAssertNotNil(fetchedBookByUrl)
    }

    func testAccumulatedProgress() {
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let book2 = StubFactory.book(title: "book2", duration: 100)

        let folder = self.generateFolder(title: "folder", books: [book1, book2])

        let emptyProgress = folder.progress

        XCTAssert(emptyProgress == 0.0)

        book1.setCurrentTime(50)
        book2.setCurrentTime(50)

        let halfProgress = folder.progress

        XCTAssert(halfProgress == 0.5)

        book1.setCurrentTime(100)
        book2.setCurrentTime(100)

        let completedProgress = folder.progress

        XCTAssert(completedProgress == 1.0)
    }

    func testNextBook() {
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let book2 = StubFactory.book(title: "book2", duration: 100)

        let folder = self.generateFolder(title: "playlist", books: [book1, book2])

        let nextBook = folder.getNextBook(after: book1)

        XCTAssert(nextBook == book2)
    }
}
