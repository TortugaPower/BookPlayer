//
//  ImportOperationTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 9/13/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
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
    }

    func testProcessOneFile() {
        let filename = "file.txt"
        let bookContents = "bookcontents".data(using: .utf8)!
        let documentsFolder = DataManager.getDocumentsFolderURL()
        let destinationFolder = DataManager.getProcessedFolderURL()

        // Add test file to Documents folder
        let fileUrl = DataTestUtils.generateTestFile(name: filename, contents: bookContents, destinationFolder: documentsFolder)

        let promise = XCTestExpectation(description: "Process file")
        let promiseFile = expectation(forNotification: .processingFile, object: nil)

        let operation = ImportOperation(files: [fileUrl])

        operation.completionBlock = {
          // Test file should no longer be in the Documents folder
          XCTAssert(!FileManager.default.fileExists(atPath: fileUrl.path))
          XCTAssertNotNil(operation.files.first)
          XCTAssertNotNil(operation.processedFiles.first)

          let file = operation.files.first!
          let processedFile = operation.processedFiles.first!

          // Test file exists in new location
          XCTAssert(!FileManager.default.fileExists(atPath: file.path))
          XCTAssert(FileManager.default.fileExists(atPath: processedFile.path))

          let content = FileManager.default.contents(atPath: processedFile.path)!
          XCTAssert(content == bookContents)

          promise.fulfill()
        }

        operation.start()

        wait(for: [promise, promiseFile], timeout: 15)
    }
}
