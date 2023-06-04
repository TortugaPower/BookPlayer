//
//  ItemDetailsViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 5/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import BookPlayerKit
import Combine

class ItemDetailsViewModel: BaseViewModel<ItemDetailsCoordinator> {
  /// Possible routes for the screen
  enum Routes {
    case cancel
    case done
  }

  enum Events {
    case showAlert(content: BPAlertContent)
    case showLoader(flag: Bool)
  }

  /// Item being modified
  let item: SimpleLibraryItem
  /// Library service used for modifications
  let libraryService: LibraryServiceProtocol
  /// Service to sync new artwork
  let syncService: SyncServiceProtocol
  /// View model for the SwiftUI form
  let formViewModel: ItemDetailsFormViewModel
  /// Callback to handle actions on this screen
  public var onTransition: Transition<Routes>?

  private var eventsPublisher = InterfaceUpdater<ItemDetailsViewModel.Events>()

  private var disposeBag = Set<AnyCancellable>()

  /// Initializer
  init(
    item: SimpleLibraryItem,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.item = item
    self.libraryService = libraryService
    self.syncService = syncService
    self.formViewModel = ItemDetailsFormViewModel(item: item)
  }

  func observeEvents() -> AnyPublisher<ItemDetailsViewModel.Events, Never> {
    eventsPublisher.eraseToAnyPublisher()
  }

  func handleCancelAction() {
    onTransition?(.cancel)
  }

  func handleSaveAction() {
    var cacheKey = item.relativePath

    let storedTitle = libraryService.getItemProperty(
      #keyPath(LibraryItem.title),
      relativePath: item.relativePath
    ) as? String

    if storedTitle != formViewModel.title {
      switch item.type {
      case .book:
        libraryService.renameBook(at: item.relativePath, with: formViewModel.title)
      case .bound, .folder:
        do {
          let newRelativePath = try libraryService.renameFolder(at: item.relativePath, with: formViewModel.title)
          cacheKey = newRelativePath
          syncService.scheduleRenameFolder(at: item.relativePath, name: formViewModel.title)
        } catch {
          sendEvent(.showAlert(content: BPAlertContent.errorAlert(message: error.localizedDescription)))
          return
        }
      }
    }

    let storedDetails = libraryService.getItemProperty(
      #keyPath(LibraryItem.details),
      relativePath: item.relativePath
    ) as? String

    if formViewModel.showAuthor,
       storedDetails != formViewModel.author {
      libraryService.updateDetails(at: item.relativePath, details: formViewModel.author)
    }

    guard formViewModel.artworkIsUpdated else {
      onTransition?(.done)
      return
    }

    guard let imageData = formViewModel.selectedImage?.jpegData(compressionQuality: 0.3) else {
      sendEvent(.showAlert(content: BPAlertContent.errorAlert(message: "Failed to process artwork")))
      return
    }

    Task { @MainActor [cacheKey, imageData, weak self] in
      guard let self = self else { return }

      self.sendEvent(.showLoader(flag: true))

      do {
        try await self.syncService.uploadArtwork(relativePath: item.relativePath, data: imageData)
        await ArtworkService.removeCache(for: item.relativePath)
        await ArtworkService.storeInCache(imageData, for: cacheKey)
        self.sendEvent(.showLoader(flag: false))
        self.onTransition?(.done)
      } catch {
        self.sendEvent(.showLoader(flag: false))
        self.sendEvent(.showAlert(content: BPAlertContent.errorAlert(message: error.localizedDescription)))
      }
    }
  }

  private func sendEvent(_ event: ItemDetailsViewModel.Events) {
    eventsPublisher.send(event)
  }
}
