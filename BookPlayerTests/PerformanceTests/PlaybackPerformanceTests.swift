//
//  PlaybackPerformanceTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 8/9/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

final class PlaybackPerformanceTests: XCTestCase {

  var sut: LibraryService!

  override func setUpWithError() throws {
    DataTestUtils.clearFolderContents(url: DataManager.getProcessedFolderURL())
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let bookMetadataService = BookMetadataService()
    self.sut = LibraryService()
    self.sut.setup(dataManager: dataManager, bookMetadataService: bookMetadataService)
    _ = self.sut.getLibrary()
  }

  override func tearDownWithError() throws {
    self.sut = nil
  }

  func testFolderProgressUpdatePerformance() async throws {
    /// Setup a test folder with 3000 ibooks inside it
    let folder = try self.sut.createFolder(with: "test-folder", inside: nil)
    let urls = Array(stride(from: 0, to: 3000, by: 1)).map({ URL(string: "test-book-\($0).mp3")! })
    _ = await self.sut.insertItems(from: urls, parentPath: folder.relativePath)

    self.measure(metrics: [XCTCPUMetric()]) {
      /// This is called by the `PlayerManager` when the currently playing book changes its progress percentage
      self.sut.recursiveFolderProgressUpdate(from: folder.relativePath)
    }
  }
}
