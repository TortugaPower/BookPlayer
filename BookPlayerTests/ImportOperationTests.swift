//
//  ImportOperationTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 9/13/18.
//  Copyright © 2018 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

// MARK: - processFiles()

class ImportOperationTests: XCTestCase {
  override func setUp() {
    super.setUp()
    // Put setup code here. This method is called before the invocation of each test method in the class.
    let documentsFolder = DataManager.getDocumentsFolderURL()
    DataTestUtils.clearFolderContents(url: documentsFolder)
    let sharedFolder = DataManager.getSharedFilesFolderURL()
    DataTestUtils.clearFolderContents(url: sharedFolder)
  }

  func testProcessOneFile() {
    let filename = "file.txt"
    let bookContents = "bookcontents".data(using: .utf8)!
    let documentsFolder = DataManager.getDocumentsFolderURL()

    // Add test file to Documents folder
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

    let promise = XCTestExpectation(description: "Process file")
    let promiseFile = expectation(forNotification: .processingFile, object: nil)
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    let operation = ImportOperation(files: [fileUrl],
                                    libraryService: libraryService)

    operation.completionBlock = {
      // Test file should no longer be in the Documents folder,
      // but when testing on simulator, the security scope is resolved
      XCTAssert(!FileManager.default.fileExists(atPath: fileUrl.path))

      XCTAssertNotNil(operation.files.first)
      XCTAssertNotNil(operation.processedFiles.first)

      let processedFile = operation.processedFiles.first!

      // Test file exists in new location
      XCTAssert(FileManager.default.fileExists(atPath: processedFile.path))

      let content = FileManager.default.contents(atPath: processedFile.path)!
      XCTAssert(content == bookContents)

      promise.fulfill()
    }

    operation.start()

    wait(for: [promise, promiseFile], timeout: 15)
  }

  func testProcessFileFromSharedFolder() {
    let filename = "shared_file.txt"
    let bookContents = "sharedbookcontents".data(using: .utf8)!
    let sharedFolder = DataManager.getSharedFilesFolderURL()

    // Add test file to the App Group SharedFiles folder (Share-extension drop location)
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: sharedFolder)

    let promise = XCTestExpectation(description: "Process shared file")
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    let operation = ImportOperation(files: [fileUrl], libraryService: libraryService)

    operation.completionBlock = {
      // Source in SharedFiles should be cleaned up after import (isAppManagedSource)
      XCTAssertFalse(FileManager.default.fileExists(atPath: fileUrl.path))

      XCTAssertNotNil(operation.processedFiles.first)
      let processedFile = operation.processedFiles.first!
      XCTAssert(FileManager.default.fileExists(atPath: processedFile.path))
      XCTAssertEqual(FileManager.default.contents(atPath: processedFile.path), bookContents)

      promise.fulfill()
    }

    operation.start()

    wait(for: [promise], timeout: 15)
  }

  func testProcessFileFromInboxFolder() throws {
    let filename = "inbox_file.txt"
    let bookContents = "inboxbookcontents".data(using: .utf8)!
    let inboxFolder = DataManager.getInboxFolderURL()
    try FileManager.default.createDirectory(at: inboxFolder, withIntermediateDirectories: true)

    // Add test file to the Documents/Inbox folder (system inbox for document interactions)
    let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: inboxFolder)

    let promise = XCTestExpectation(description: "Process inbox file")
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let audioMetadataService = AudioMetadataService()
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager, audioMetadataService: audioMetadataService)
    let operation = ImportOperation(files: [fileUrl], libraryService: libraryService)

    operation.completionBlock = {
      // Source in Inbox (a Documents subfolder) should be cleaned up after import
      XCTAssertFalse(FileManager.default.fileExists(atPath: fileUrl.path))

      XCTAssertNotNil(operation.processedFiles.first)
      let processedFile = operation.processedFiles.first!
      XCTAssert(FileManager.default.fileExists(atPath: processedFile.path))
      XCTAssertEqual(FileManager.default.contents(atPath: processedFile.path), bookContents)

      promise.fulfill()
    }

    operation.start()

    wait(for: [promise], timeout: 15)
  }
}
