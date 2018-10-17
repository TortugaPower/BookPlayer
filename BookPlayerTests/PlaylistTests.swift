//
//  PlaylistTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 6/19/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import XCTest
@testable import BookPlayer

class PlaylistTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    func generateBook(title: String, duration: Double) -> Book {
        let dummyUrl = URL(fileURLWithPath: title)
        let bookUrl = FileItem(originalUrl: dummyUrl, processedUrl: dummyUrl, destinationFolder: dummyUrl)
        let book = DataManager.createBook(from: bookUrl)
        book.duration = duration

        return book
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
        let book1 = generateBook(title: "book1", duration: 100)

        let playlist = generatePlaylist(title: "playlist", books: [book1])

        let fetchedBookByIdentifier = playlist.getBook(with: "book1")

        XCTAssertNotNil(fetchedBookByIdentifier)

        let dummyUrl = URL(fileURLWithPath: "book1")
        let fetchedBookByUrl = playlist.getBook(with: dummyUrl)

        XCTAssertNotNil(fetchedBookByUrl)
    }

    func testAccumulatedProgress() {
        let book1 = generateBook(title: "book1", duration: 100)
        let book2 = generateBook(title: "book2", duration: 100)

        let playlist = generatePlaylist(title: "playlist", books: [book1, book2])

        let emptyProgress = playlist.totalProgress()

        XCTAssert(emptyProgress == 0.0)

        book1.currentTime = 50
        book2.currentTime = 50

        let halfProgress = playlist.totalProgress()

        XCTAssert(halfProgress == 0.5)

        book1.currentTime = 100
        book2.currentTime = 100

        let completedProgress = playlist.totalProgress()

        XCTAssert(completedProgress == 1.0)
    }

    func testRemainingBooks() {
        let book1 = generateBook(title: "book1", duration: 100)
        let book2 = generateBook(title: "book2", duration: 100)

        let playlist = generatePlaylist(title: "playlist", books: [book1, book2])

        let twoRemainingBooks = playlist.getRemainingBooks()

        XCTAssert(twoRemainingBooks.count == 2)

        book1.currentTime = 100

        let oneRemainingBook = playlist.getRemainingBooks()
        XCTAssert(oneRemainingBook.count == 1)

        book2.currentTime = 100

        let noRemainingBook = playlist.getRemainingBooks()
        XCTAssert(noRemainingBook.count == 0)
    }
}
