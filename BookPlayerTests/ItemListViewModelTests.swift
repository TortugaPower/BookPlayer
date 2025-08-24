//
//  ItemListViewModelTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 2/11/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class ItemListViewModelTests: XCTestCase {
  var sut: ItemListUIViewModel!
  var subscription: AnyCancellable?
  var dataManager: DataManager!

  override func setUp() {
    self.dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager)
    let playerManagerMock = PlayerManagerProtocolMock()
    playerManagerMock.currentItemPublisherReturnValue = Just(nil).eraseToAnyPublisher()
    let singleFileDownloadService = SingleFileDownloadService(networkClient: NetworkClient())
    let hardcoverService = HardcoverService()
    hardcoverService.setup(libraryService: libraryService)
    let syncServiceMock = SyncServiceProtocolMock()

    self.sut = ItemListUIViewModel(
      folderRelativePath: nil,
      playerManager: playerManagerMock,
      singleFileDownloadService: singleFileDownloadService,
      libraryService: libraryService,
      playbackService: PlaybackServiceProtocolMock(),
      syncService: syncServiceMock, 
      importManager: ImportManager(libraryService: libraryService), 
      listRefreshService: ListSyncRefreshService(
        playerManager: playerManagerMock,
        syncService: syncServiceMock,
        playerLoaderService: PlayerLoaderService()
      ),
      hardcoverService: hardcoverService,
      themeAccent: .blue
    )

    let library = libraryService.getLibrary()
    library.addToItems(
      StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
    )
    library.addToItems(
      StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
    )
    library.addToItems(
      StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)
    )
    library.addToItems(
      StubFactory.book(dataManager: self.dataManager, title: "book4", duration: 100)
    )
    self.dataManager.saveContext()
  }

  func testLoadingInitialItems() {
    self.sut.loadInitialItems()
    XCTAssert(self.sut.items.count == 4)
    XCTAssert(self.sut.offset == 4)
    XCTAssert(self.sut.maxItems == 4)
  }

  func testLoadingInitialItemsPagination() {
    self.sut.loadInitialItems(pageSize: 2)
    XCTAssert(self.sut.items.count == 2)
    XCTAssert(self.sut.offset == 2)
    XCTAssert(self.sut.maxItems == 4)

    self.sut.loadInitialItems(pageSize: 4)
    XCTAssert(self.sut.items.count == 4)
    XCTAssert(self.sut.offset == 4)
    XCTAssert(self.sut.maxItems == 4)
  }

  func testLoadingNextItems() {
    self.subscription?.cancel()
    let expectation = XCTestExpectation(description: "Item updates notification")

    self.subscription = self.sut.observeEvents().sink(receiveValue: { event in
      if case .newData = event {
        expectation.fulfill()
      }
    })

    self.sut.loadNextItems()
    wait(for: [expectation], timeout: 1)
    XCTAssert(self.sut.items.count == 4)
    XCTAssert(self.sut.offset == 4)
    XCTAssert(self.sut.maxItems == 4)
  }

  func testLoadingNextItemsPagination() {
    self.subscription?.cancel()
    let expectation = XCTestExpectation(description: "Item updates notification")

    self.subscription = self.sut.observeEvents().sink(receiveValue: { event in
      if case .newData = event {
        expectation.fulfill()
      }
    })

    self.sut.loadNextItems(pageSize: 2)
    wait(for: [expectation], timeout: 1)
    XCTAssert(self.sut.items.count == 2)
    XCTAssert(self.sut.offset == 2)
    XCTAssert(self.sut.maxItems == 4)

    self.sut.loadNextItems(pageSize: 2)
    XCTAssert(self.sut.items.count == 4)
    XCTAssert(self.sut.offset == 4)
    XCTAssert(self.sut.maxItems == 4)
  }

  func testLoadingAllItemsIfNeeded() {
    self.subscription?.cancel()
    let expectation = XCTestExpectation(description: "Item updates notification")

    self.subscription = self.sut.observeEvents().sink(receiveValue: { event in
      if case .newData = event {
        expectation.fulfill()
      }
    })

    self.sut.loadAllItemsIfNeeded()
    wait(for: [expectation], timeout: 1)
    XCTAssert(self.sut.items.count == 4)
    XCTAssert(self.sut.offset == 4)
    XCTAssert(self.sut.maxItems == 4)
  }
}
