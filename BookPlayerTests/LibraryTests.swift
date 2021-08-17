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

      let library = try! StubFactory.library()
      DataManager.delete(library)

      let documentsFolder = DataManager.getDocumentsFolderURL()
      DataTestUtils.clearFolderContents(url: documentsFolder)
      let processedFolder = DataManager.getProcessedFolderURL()
      DataTestUtils.clearFolderContents(url: processedFolder)
    }

    func testRelativePath() throws {
        let library = try StubFactory.library()
        let book1 = StubFactory.book(title: "book1", duration: 100)
        let book2 = StubFactory.book(title: "book2", duration: 100)
        let book3 = StubFactory.book(title: "book3", duration: 100)

        let folder = try StubFactory.folder(title: "folder")
        folder.insert(item: book1)
        folder.insert(item: book2)
        let folder2 = try StubFactory.folder(title: "folder2")
        folder2.insert(item: book3)
        folder2.insert(item: folder)

        XCTAssert(folder.relativePath == "folder2/folder")
        XCTAssert(folder2.relativePath == "folder2")
        XCTAssert(book1.relativePath == "folder2/folder/book1.txt")
        XCTAssert(book2.relativePath == "folder2/folder/book2.txt")
        XCTAssert(book3.relativePath == "folder2/book3.txt")

        library.insert(item: folder)

        XCTAssert(folder.relativePath == "folder")
        XCTAssert(folder2.relativePath == "folder2")
        XCTAssert(book1.relativePath == "folder/book1.txt")
        XCTAssert(book2.relativePath == "folder/book2.txt")
        XCTAssert(book3.relativePath == "folder2/book3.txt")

        library.insert(item: book3)

        XCTAssert(book3.relativePath == "book3.txt")
    }
}
