//
//  StorageViewModelTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 16/11/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

final class StorageViewModelMissingFileTests: XCTestCase {
  private var viewModel: StorageViewModel!
  private var directoryURL: URL!
  private let testPath = "/dev/null"

  func testSetupItem(in folder: String, filename: String) {
    let bookContents = "bookcontents".data(using: .utf8)!
    let documentsURL = DataManager.getDocumentsFolderURL()

    self.directoryURL = try! FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: documentsURL,
      create: true
    )

    let folderURL = try! DataTestUtils.generateTestFolder(name: folder, destinationFolder: self.directoryURL)

    // Add test file to the Processed folder
    _ = DataTestUtils.generateTestFile(name: filename,
                                       contents: bookContents,
                                       destinationFolder: folderURL)

    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: self.testPath))
    let libraryService = LibraryService(dataManager: dataManager)
    self.viewModel = StorageViewModel(libraryService: libraryService,
                                      folderURL: self.directoryURL)
  }

  func testSetup(with filename: String) {
    let bookContents = "bookcontents".data(using: .utf8)!

    let documentsURL = DataManager.getDocumentsFolderURL()

    self.directoryURL = try! FileManager.default.url(
      for: .itemReplacementDirectory,
      in: .userDomainMask,
      appropriateFor: documentsURL,
      create: true
    )

    // Add test file to the Processed folder
    _ = DataTestUtils.generateTestFile(name: filename,
                                       contents: bookContents,
                                       destinationFolder: self.directoryURL)

    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: self.testPath))
    let libraryService = LibraryService(dataManager: dataManager)
    _ = libraryService.getLibrary()
    self.viewModel = StorageViewModel(libraryService: libraryService,
                                      folderURL: self.directoryURL)
  }

  func testGetBrokenItems() {
    self.testSetup(with: "file-storage1.txt")

    let expectation = XCTestExpectation(description: "Items load expectation")
    expectation.isInverted = true
    wait(for: [expectation], timeout: 5.0)

    let loadedItems: [StorageItem] = self.viewModel.publishedFiles
    XCTAssert(loadedItems.count == 1)

    let brokenItems = self.viewModel.getBrokenItems()
    XCTAssert(brokenItems.count == 1)
  }

  func testHandleFixItem() throws {
    self.testSetup(with: "file-storage2.txt")
    let item = StorageItem(title: "item",
                           fileURL: self.directoryURL.appendingPathComponent("file-storage2.txt"),
                           path: self.directoryURL.path,
                           size: 10,
                           showWarning: true)
    // Trigger library creation for this test
    XCTAssertTrue(self.viewModel.library.items?.allObjects.isEmpty ?? false)
    try self.viewModel.handleFix(for: item)

    let expectation = XCTestExpectation(description: "Items load expectation")
    expectation.isInverted = true
    wait(for: [expectation], timeout: 5.0)

    let loadedItems: [StorageItem] = viewModel.publishedFiles
    XCTAssert(loadedItems.count == 1)

    let brokenItems = self.viewModel.getBrokenItems()
    XCTAssert(brokenItems.isEmpty)
  }

  func testUnicodeMissingItem() throws {
    let folderName = "Maigretův první případ"
    let bookName = "idyllica_04_herrick_64kb.mp3"

    self.testSetupItem(in: folderName, filename: bookName)

    let expectation = XCTestExpectation(description: "Items load expectation")
    expectation.isInverted = true
    wait(for: [expectation], timeout: 5.0)

    guard let item = viewModel.publishedFiles.first else {
      return
    }
    let loadedFileURL: URL = item.fileURL

    // Manual recreation of folder and book inside library
    let folder = try self.viewModel.libraryService.createFolder(with: folderName, inside: nil)
    let book = self.viewModel.libraryService.createBook(from: loadedFileURL)
    try viewModel.libraryService.moveItems([book.relativePath], inside: folder.relativePath)

    XCTAssertFalse(self.viewModel.shouldShowWarning(for: "Maigretův první případ/idyllica_04_herrick_64kb.mp3"))
  }
}
