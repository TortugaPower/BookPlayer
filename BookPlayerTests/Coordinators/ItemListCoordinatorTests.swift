//
//  ItemListCoordinatorTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class LibraryListCoordinatorTests: XCTestCase {
  var libraryListCoordinator: LibraryListCoordinator!
  var dataManager: DataManager!

  override func setUp() {
    self.dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let libraryService = LibraryService(dataManager: self.dataManager)

    self.libraryListCoordinator = LibraryListCoordinator(
      navigationController: UINavigationController(),
      library: StubFactory.library(dataManager: dataManager),
      playerManager: PlayerManagerMock(),
      importManager: ImportManager(libraryService: libraryService),
      libraryService: libraryService
    )

    self.libraryListCoordinator.start()
  }

  func testInitialState() {
    XCTAssert(self.libraryListCoordinator.childCoordinators.isEmpty)
    XCTAssert(self.libraryListCoordinator.shouldShowImportScreen())
    XCTAssert(self.libraryListCoordinator.shouldHandleImport())
  }

  func testDocumentPickerDelegate() {
    XCTAssertNotNil(self.libraryListCoordinator.documentPickerDelegate)
  }

  func testShowFolder() {
    let folder = try! StubFactory.folder(dataManager: self.dataManager, title: "folder 1")
    self.libraryListCoordinator.library.insert(item: folder)

    self.libraryListCoordinator.showFolder(folder)
    XCTAssert(self.libraryListCoordinator.childCoordinators.first is ItemListCoordinator)
    XCTAssertFalse(self.libraryListCoordinator.shouldShowImportScreen())
    XCTAssertFalse(self.libraryListCoordinator.shouldHandleImport())
  }

  func testShowPlayer() {
    self.libraryListCoordinator.showPlayer()
    XCTAssert(self.libraryListCoordinator.childCoordinators.first is PlayerCoordinator)
  }

  func testShowSettings() {
    self.libraryListCoordinator.showSettings()
    XCTAssert(self.libraryListCoordinator.childCoordinators.first is SettingsCoordinator)
  }

  func testShowImport() {
    self.libraryListCoordinator.showImport()
    XCTAssert(self.libraryListCoordinator.childCoordinators.first is ImportCoordinator)
  }

  func testShowItemContentsFolder() {
    let folder = try! StubFactory.folder(dataManager: self.dataManager, title: "folder 1")
    self.libraryListCoordinator.library.insert(item: folder)

    self.libraryListCoordinator.showItemContents(folder)
    XCTAssert(self.libraryListCoordinator.childCoordinators.first is ItemListCoordinator)
  }

  func testShowItemContentsBook() {
    let book = StubFactory.book(dataManager: self.dataManager, title: "book 1", duration: 10)
    self.libraryListCoordinator.library.insert(item: book)

    self.libraryListCoordinator.showItemContents(book)
    XCTAssert(self.libraryListCoordinator.childCoordinators.first is PlayerCoordinator)
  }
}

class FolderListCoordinatorTests: XCTestCase {
  var folderListCoordinator: FolderListCoordinator!

  override func setUp() {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let libraryService = LibraryService(dataManager: dataManager)

    self.folderListCoordinator = FolderListCoordinator(
      navigationController: UINavigationController(),
      library: StubFactory.library(dataManager: dataManager),
      folder: try! StubFactory.folder(dataManager: dataManager, title: "folder 1"),
      playerManager: PlayerManagerMock(),
      importManager: ImportManager(libraryService: libraryService),
      libraryService: libraryService
    )

    self.folderListCoordinator.start()
  }

  func testDocumentPickerDelegate() {
    XCTAssertNotNil(self.folderListCoordinator.documentPickerDelegate)
  }
}
