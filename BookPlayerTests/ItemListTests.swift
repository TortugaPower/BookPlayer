//
//  ItemListTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 2/11/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import Combine
import XCTest

class ItemListTests: XCTestCase {
  var viewModel: FolderListViewModel!
  var subscription: AnyCancellable?

  override func setUp() {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))

    let playerManager = PlayerManager(dataManager: dataManager,
                                      watchConnectivityService: WatchConnectivityService(dataManager: dataManager))

    self.viewModel = FolderListViewModel(folder: nil,
                                         library: dataManager.createLibrary(),
                                         player: playerManager,
                                         dataManager: dataManager,
                                         themeAccent: .blue)

    self.viewModel.library.insert(
      item: StubFactory.book(dataManager: self.viewModel.dataManager, title: "book1", duration: 100)
    )
    self.viewModel.library.insert(
      item: StubFactory.book(dataManager: self.viewModel.dataManager, title: "book2", duration: 100)
    )
    self.viewModel.library.insert(
      item: StubFactory.book(dataManager: self.viewModel.dataManager, title: "book3", duration: 100)
    )
    self.viewModel.library.insert(
      item: StubFactory.book(dataManager: self.viewModel.dataManager, title: "book4", duration: 100)
    )
  }

  func testLoadingInitialItems() {
    let loadedItems = self.viewModel.loadInitialItems()
    XCTAssert(loadedItems.count == 4)
    XCTAssert(self.viewModel.items.count == 4)
    XCTAssert(self.viewModel.offset == 4)
    XCTAssert(self.viewModel.maxItems == 4)
  }

  func testLoadingInitialItemsPagination() {
    let partialLoadedItems = self.viewModel.loadInitialItems(pageSize: 2)
    XCTAssert(partialLoadedItems.count == 2)
    XCTAssert(self.viewModel.items.count == 2)
    XCTAssert(self.viewModel.offset == 2)
    XCTAssert(self.viewModel.maxItems == 4)

    let completeLoadedItems = self.viewModel.loadInitialItems(pageSize: 4)
    XCTAssert(completeLoadedItems.count == 4)
    XCTAssert(self.viewModel.items.count == 4)
    XCTAssert(self.viewModel.offset == 4)
    XCTAssert(self.viewModel.maxItems == 4)
  }

  func testLoadingNextItems() {
    self.subscription?.cancel()
    let expectation = XCTestExpectation(description: "Item updates notification")

    var loadedItems: [SimpleLibraryItem]!
    self.subscription = self.viewModel.itemsUpdates.sink(receiveValue: { items in
      loadedItems = items
      expectation.fulfill()
    })

    self.viewModel.loadNextItems()
    XCTAssert(loadedItems.count == 4)
    XCTAssert(self.viewModel.items.count == 4)
    XCTAssert(self.viewModel.offset == 4)
    XCTAssert(self.viewModel.maxItems == 4)
  }

  func testLoadingNextItemsPagination() {
    self.subscription?.cancel()
    let expectation = XCTestExpectation(description: "Item updates notification")

    var loadedItems: [SimpleLibraryItem]!
    self.subscription = self.viewModel.itemsUpdates.sink(receiveValue: { items in
      loadedItems = items
      expectation.fulfill()
    })

    self.viewModel.loadNextItems(pageSize: 2)
    XCTAssert(loadedItems.count == 2)
    XCTAssert(self.viewModel.items.count == 2)
    XCTAssert(self.viewModel.offset == 2)
    XCTAssert(self.viewModel.maxItems == 4)

    self.viewModel.loadNextItems(pageSize: 2)
    XCTAssert(self.viewModel.items.count == 4)
    XCTAssert(self.viewModel.offset == 4)
    XCTAssert(self.viewModel.maxItems == 4)
  }

  func testLoadingAllItemsIfNeeded() {
    self.subscription?.cancel()
    let expectation = XCTestExpectation(description: "Item updates notification")

    var loadedItems: [SimpleLibraryItem]!
    self.subscription = self.viewModel.itemsUpdates.sink(receiveValue: { items in
      loadedItems = items
      expectation.fulfill()
    })

    self.viewModel.loadAllItemsIfNeeded()
    XCTAssert(loadedItems.count == 4)
    XCTAssert(self.viewModel.items.count == 4)
    XCTAssert(self.viewModel.offset == 4)
    XCTAssert(self.viewModel.maxItems == 4)
  }
}
