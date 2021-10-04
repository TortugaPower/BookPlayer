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
  let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))

    override func setUp() {
      super.setUp()

      let library = StubFactory.library(dataManager: self.dataManager)
      self.dataManager.delete(library)

      let documentsFolder = DataManager.getDocumentsFolderURL()
      DataTestUtils.clearFolderContents(url: documentsFolder)
      let processedFolder = DataManager.getProcessedFolderURL()
      DataTestUtils.clearFolderContents(url: processedFolder)
    }

    func testRelativePath() throws {
        let library = StubFactory.library(dataManager: self.dataManager)
        let book1 = StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
        let book2 = StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
        let book3 = StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)

        let folder = try StubFactory.folder(dataManager: self.dataManager, title: "folder")
        folder.insert(item: book1)
        folder.insert(item: book2)
        let folder2 = try StubFactory.folder(dataManager: self.dataManager, title: "folder2")
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
