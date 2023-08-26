//
//  DataTestUtils.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 9/13/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import XCTest

class DataTestUtils: XCTest {
  class func generateTestFile(name: String, contents: Data, destinationFolder: URL) -> URL {
    let destination = destinationFolder.appendingPathComponent(name)

    XCTAssertNoThrow(try contents.write(to: destination))
    XCTAssert(FileManager.default.fileExists(atPath: destination.path))

    return destination
  }

  class func generateTestFolder(name: String, destinationFolder: URL) throws -> URL {
    let destination = destinationFolder.appendingPathComponent(name)

    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: nil)

    return destination
  }

  class func clearFolderContents(url: URL) {
    do {
      let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
      for url in urls {
        try FileManager.default.removeItem(at: url)
      }
    } catch {
      print("Exception while clearing folder contents")
    }
  }
}
