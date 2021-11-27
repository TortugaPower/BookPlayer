//
//  ItemListViewModelTests.swift
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

class ItemListViewModelTests: XCTestCase {
  var sut: ItemListViewModel!
  var subscription: AnyCancellable?
  var dataManager: DataManager!

  override func setUp() {
    self.dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))

    self.sut = ItemListViewModel(folder: nil,
                                 library: StubFactory.library(dataManager: dataManager),
                                 playerManager: PlayerManagerMock(),
                                 libraryService: LibraryService(dataManager: dataManager),
                                 themeAccent: .blue)

    self.sut.library.insert(
      item: StubFactory.book(dataManager: self.dataManager, title: "book1", duration: 100)
    )
    self.sut.library.insert(
      item: StubFactory.book(dataManager: self.dataManager, title: "book2", duration: 100)
    )
    self.sut.library.insert(
      item: StubFactory.book(dataManager: self.dataManager, title: "book3", duration: 100)
    )
    self.sut.library.insert(
      item: StubFactory.book(dataManager: self.dataManager, title: "book4", duration: 100)
    )
  }

  func testLoadingInitialItems() {
    let loadedItems = self.sut.loadInitialItems()
    XCTAssert(loadedItems.count == 4)
    XCTAssert(self.sut.items.count == 4)
    XCTAssert(self.sut.offset == 4)
    XCTAssert(self.sut.maxItems == 4)
  }

  func testLoadingInitialItemsPagination() {
    let partialLoadedItems = self.sut.loadInitialItems(pageSize: 2)
    XCTAssert(partialLoadedItems.count == 2)
    XCTAssert(self.sut.items.count == 2)
    XCTAssert(self.sut.offset == 2)
    XCTAssert(self.sut.maxItems == 4)

    let completeLoadedItems = self.sut.loadInitialItems(pageSize: 4)
    XCTAssert(completeLoadedItems.count == 4)
    XCTAssert(self.sut.items.count == 4)
    XCTAssert(self.sut.offset == 4)
    XCTAssert(self.sut.maxItems == 4)
  }

  func testLoadingNextItems() {
    self.subscription?.cancel()
    let expectation = XCTestExpectation(description: "Item updates notification")

    var loadedItems: [SimpleLibraryItem]!
    self.subscription = self.sut.itemsUpdates.sink(receiveValue: { items in
      loadedItems = items
      expectation.fulfill()
    })

    self.sut.loadNextItems()
    XCTAssert(loadedItems.count == 4)
    XCTAssert(self.sut.items.count == 4)
    XCTAssert(self.sut.offset == 4)
    XCTAssert(self.sut.maxItems == 4)
  }

  func testLoadingNextItemsPagination() {
    self.subscription?.cancel()
    let expectation = XCTestExpectation(description: "Item updates notification")

    var loadedItems: [SimpleLibraryItem]!
    self.subscription = self.sut.itemsUpdates.sink(receiveValue: { items in
      loadedItems = items
      expectation.fulfill()
    })

    self.sut.loadNextItems(pageSize: 2)
    XCTAssert(loadedItems.count == 2)
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

    var loadedItems: [SimpleLibraryItem]!
    self.subscription = self.sut.itemsUpdates.sink(receiveValue: { items in
      loadedItems = items
      expectation.fulfill()
    })

    self.sut.loadAllItemsIfNeeded()
    XCTAssert(loadedItems.count == 4)
    XCTAssert(self.sut.items.count == 4)
    XCTAssert(self.sut.offset == 4)
    XCTAssert(self.sut.maxItems == 4)
  }
}
