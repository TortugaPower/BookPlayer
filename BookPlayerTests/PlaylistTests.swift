//
//  PlaylistTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 6/19/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

@testable import BookPlayer
import XCTest

class PlaylistTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func generatePlaylist(title: String, books: [Book]) -> Playlist {
        return DataManager.createPlaylist(title: title, books: books)
    }

    func testGetNilBook() {
        let playlist = generatePlaylist(title: "playlist", books: [])

        let fetchedBookByIdentifier = playlist.getBook(with: "book1")

        XCTAssertNil(fetchedBookByIdentifier)

        let dummyUrl = URL(fileURLWithPath: "book1")
        let fetchedBookByUrl = playlist.getBook(with: dummyUrl)

        XCTAssertNil(fetchedBookByUrl)
    }

    func testGetBook() {
        let book1 = StubFactory.book(title: "book1", duration: 100)

        let playlist = generatePlaylist(title: "playlist", books: [book1])

        let fetchedBookByIdentifier = playlist.getBook(with: "book1")

        XCTAssertNotNil(fetchedBookByIdentifier)

        let dummyUrl = URL(fileURLWithPath: "book1")
        let fetchedBookByUrl = playlist.getBook(with: dummyUrl)

        XCTAssertNotNil(fetchedBookByUrl)
    }

    func testAccumulatedProgress() {
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let book2 = StubFactory.book(title: "book2", duration: 100)

        let playlist = generatePlaylist(title: "playlist", books: [book1, book2])

        let emptyProgress = playlist.progress

        XCTAssert(emptyProgress == 0.0)

        book1.currentTime = 50
        book2.currentTime = 50

        let halfProgress = playlist.progress

        XCTAssert(halfProgress == 0.5)

        book1.currentTime = 100
        book2.currentTime = 100

        let completedProgress = playlist.progress

        XCTAssert(completedProgress == 1.0)
    }

    func testNextBook() {
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let book2 = StubFactory.book(title: "book2", duration: 100)

        let playlist = generatePlaylist(title: "playlist", books: [book1, book2])

        let nextBook = playlist.getNextBook(after: book1)

        XCTAssert(nextBook == book2)
    }
}
