//
//  LibraryTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 19/6/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class LibraryTests: XCTestCase {
    override func setUp() {
        super.setUp()

        let library = DataManager.getLibrary()
        DataManager.delete(library)
    }

    func testRelativePath() {
        let library = DataManager.getLibrary()
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let book2 = StubFactory.book(title: "book2", duration: 100)
        let book3 = StubFactory.book(title: "book3", duration: 100)

        let folder = StubFactory.folder(title: "folder", items: [book1, book2])
        let folder2 = StubFactory.folder(title: "folder2", items: [folder, book3])

        XCTAssert(folder.relativePath == "folder2/folder")
        XCTAssert(folder2.relativePath == "folder2")
        XCTAssert(book1.relativePath == "folder2/folder/book1")
        XCTAssert(book2.relativePath == "folder2/folder/book2")
        XCTAssert(book3.relativePath == "folder2/book3")

        library.insert(item: folder)

        XCTAssert(folder.relativePath == "folder")
        XCTAssert(folder2.relativePath == "folder2")
        XCTAssert(book1.relativePath == "folder/book1")
        XCTAssert(book2.relativePath == "folder/book2")
        XCTAssert(book3.relativePath == "folder2/book3")

        library.insert(item: book3)

        XCTAssert(book3.relativePath == "book3")
    }
}
