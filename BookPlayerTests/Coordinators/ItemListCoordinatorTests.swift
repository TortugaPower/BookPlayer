//
//  ItemListCoordinatorTests.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import Foundation

import Combine
@testable import BookPlayer
@testable import BookPlayerKit
import XCTest

class LibraryListCoordinatorTests: XCTestCase {
  var libraryListCoordinator: LibraryListCoordinator!
  var dataManager: DataManager!
  var presentingController: MockNavigationController!

  override func setUp() {
    self.presentingController = MockNavigationController()
    let coreServices = AppDelegate.shared!.createCoreServicesIfNeeded(from: CoreDataStack(testPath: "/dev/null"))
    self.dataManager = coreServices.dataManager
    let libraryService = coreServices.libraryService
    _ = libraryService.getLibrary()
    let playerManagerMock = PlayerManagerProtocolMock()
    playerManagerMock.currentItemPublisherReturnValue = Just(nil).eraseToAnyPublisher()
    playerManagerMock.currentSpeedPublisherReturnValue = Just(1.0).eraseToAnyPublisher()
    playerManagerMock.isPlayingPublisherReturnValue = Just(false).eraseToAnyPublisher()
    let syncServiceMock = SyncServiceProtocolMock()
    let keychainServiceMock = KeychainServiceMock()
    let singleFileDownloadService = SingleFileDownloadService(networkClient: NetworkClient(keychain: keychainServiceMock))
    let hardcoverService = HardcoverService()
    hardcoverService.setup(libraryService: libraryService)

    self.libraryListCoordinator = LibraryListCoordinator(
      flow: .pushFlow(navigationController: self.presentingController),
      playerManager: playerManagerMock,
      singleFileDownloadService: singleFileDownloadService,
      libraryService: libraryService,
      playbackService: coreServices.playbackService,
      syncService: syncServiceMock,
      importManager: ImportManager(libraryService: libraryService),
      listRefreshService: ListSyncRefreshService(
        playerManager: playerManagerMock,
        syncService: syncServiceMock,
        playerLoaderService: PlayerLoaderService()
      ),
      accountService: coreServices.accountService,
      jellyfinConnectionService: JellyfinConnectionService(keychainService: keychainServiceMock),
      hardcoverService: hardcoverService
    )

    self.libraryListCoordinator.start()
  }

  func testDocumentPickerDelegate() {
    XCTAssertNotNil(self.libraryListCoordinator.documentPickerDelegate)
  }

  func testShowFolder() {
    let folder = try! StubFactory.folder(dataManager: self.dataManager, title: "folder 1")
    let library = self.libraryListCoordinator.libraryService.getLibraryReference()
    library.addToItems(folder)

    self.libraryListCoordinator.showFolder(folder.relativePath)
    let folderViewController = presentingController.viewControllers.last as? ItemListViewController
    XCTAssertTrue(folderViewController?.viewModel.folderRelativePath == folder.relativePath)
    XCTAssertTrue(presentingController.horizontalStack == ["ItemListViewController", "ItemListViewController"])
  }

  @MainActor
  func testShowPlayer() {
    self.libraryListCoordinator.showPlayer()
    XCTAssert(presentingController.verticalStack == ["PlayerViewController"])
  }
}

class FolderListCoordinatorTests: XCTestCase {
  var folderListCoordinator: FolderListCoordinator!
  var presentingController: UINavigationController!

  override func setUp() {
    self.presentingController = MockNavigationController()
    let dataManager = DataManager(coreDataStack: CoreDataStack(testPath: "/dev/null"))
    let libraryService = LibraryService()
    libraryService.setup(dataManager: dataManager)
    let folder = try! StubFactory.folder(dataManager: dataManager, title: "folder 1")
    let playerManagerMock = PlayerManagerProtocolMock()
    playerManagerMock.currentItemPublisherReturnValue = Just(nil).eraseToAnyPublisher()
    let singleFileDownloadService = SingleFileDownloadService(networkClient: NetworkClient())
    let syncServiceMock = SyncServiceProtocolMock()
    let keychainServiceMock = KeychainServiceMock()
    let hardcoverService = HardcoverService()
    hardcoverService.setup(libraryService: libraryService)
    let playbackService = PlaybackService()
    playbackService.setup(libraryService: libraryService)

    self.folderListCoordinator = FolderListCoordinator(
      flow: .pushFlow(navigationController: self.presentingController),
      folderRelativePath: folder.relativePath,
      playerManager: playerManagerMock,
      singleFileDownloadService: singleFileDownloadService,
      libraryService: libraryService,
      playbackService: playbackService,
      syncService: syncServiceMock,
      importManager: ImportManager(libraryService: libraryService),
      listRefreshService: ListSyncRefreshService(
        playerManager: playerManagerMock,
        syncService: syncServiceMock,
        playerLoaderService: PlayerLoaderService()
      ),
      jellyfinConnectionService: JellyfinConnectionService(keychainService: keychainServiceMock),
      hardcoverService: hardcoverService
    )

    self.folderListCoordinator.start()
  }

  func testDocumentPickerDelegate() {
    XCTAssertNotNil(self.folderListCoordinator.documentPickerDelegate)
  }
}
