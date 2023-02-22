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
    let coreServices = AppDelegate.shared!.createCoreServicesIfNeeded(from: CoreDataStack(testPath: "/dev/null"))
    self.dataManager = coreServices.dataManager
    let libraryService = coreServices.libraryService

    self.libraryListCoordinator = LibraryListCoordinator(
      navigationController: UINavigationController(),
      playerManager: PlayerManagerMock(),
      importManager: ImportManager(libraryService: libraryService),
      libraryService: libraryService,
      playbackService: coreServices.playbackService,
      syncService: SyncServiceMock()
    )

    self.libraryListCoordinator.start()
  }

  func testInitialState() {
    XCTAssert(self.libraryListCoordinator.childCoordinators.isEmpty)
    XCTAssert(self.libraryListCoordinator.shouldShowImportScreen())
  }

  func testDocumentPickerDelegate() {
    XCTAssertNotNil(self.libraryListCoordinator.documentPickerDelegate)
  }

  func testShowFolder() {
    let folder = try! StubFactory.folder(dataManager: self.dataManager, title: "folder 1")
    let library = self.libraryListCoordinator.libraryService.getLibrary()
    library.insert(item: folder)

    self.libraryListCoordinator.showFolder(folder.relativePath)
    XCTAssert(self.libraryListCoordinator.childCoordinators.first is ItemListCoordinator)
    XCTAssertTrue(self.libraryListCoordinator.shouldShowImportScreen())
  }

  func testShowPlayer() {
    self.libraryListCoordinator.showPlayer()
    XCTAssert(self.libraryListCoordinator.childCoordinators.first is PlayerCoordinator)
  }

  func testShowImport() {
    self.libraryListCoordinator.showImport()
    XCTAssert(self.libraryListCoordinator.childCoordinators.first is ImportCoordinator)
  }
}

class FolderListCoordinatorTests: XCTestCase {
  var folderListCoordinator: FolderListCoordinator!

  override func setUp() {
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let libraryService = LibraryService(dataManager: dataManager)
    let folder = try! StubFactory.folder(dataManager: dataManager, title: "folder 1")

    self.folderListCoordinator = FolderListCoordinator(
      navigationController: UINavigationController(),
      folderRelativePath: folder.relativePath,
      playerManager: PlayerManagerMock(),
      libraryService: libraryService,
      playbackService: PlaybackService(libraryService: libraryService),
      syncService: SyncServiceMock()
    )

    self.folderListCoordinator.start()
  }

  func testDocumentPickerDelegate() {
    XCTAssertNotNil(self.folderListCoordinator.documentPickerDelegate)
  }
}
