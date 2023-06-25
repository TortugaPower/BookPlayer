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

class ItemDetailsViewModel: BaseViewModel<Coordinator> {
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
    Task { @MainActor [unowned self] in
      let cacheKey: String

      do {
        cacheKey = try await updateTitle(formViewModel.title, relativePath: item.relativePath)
      } catch {
        sendEvent(.showAlert(content: BPAlertContent.errorAlert(message: error.localizedDescription)))
        return
      }

      if formViewModel.showAuthor == true {
        await updateAuthor(formViewModel.author, relativePath: item.relativePath)
      }

      guard formViewModel.artworkIsUpdated else {
        onTransition?(.done)
        return
      }

      guard let imageData = formViewModel.selectedImage?.jpegData(compressionQuality: 0.3) else {
        sendEvent(.showAlert(content: BPAlertContent.errorAlert(message: "Failed to process artwork")))
        return
      }

      self.sendEvent(.showLoader(flag: true))

      await ArtworkService.removeCache(for: item.relativePath)
      await ArtworkService.storeInCache(imageData, for: cacheKey)
      self.syncService.scheduleUploadArtwork(relativePath: cacheKey)

      self.sendEvent(.showLoader(flag: false))
      self.onTransition?(.done)
    }
  }

  /// Update the item title if necessary
  /// - Returns: The new relative path to be used as the cache key
  func updateTitle(_ newTitle: String, relativePath: String) async throws -> String {
    var cacheKey = relativePath
    let cleanedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !cleanedTitle.isEmpty else {
      return cacheKey
    }

    let storedTitle = libraryService.getItemProperty(
      #keyPath(LibraryItem.title),
      relativePath: relativePath
    ) as? String

    guard storedTitle != cleanedTitle else {
      return cacheKey
    }

    switch item.type {
    case .book:
      await libraryService.renameBook(at: relativePath, with: cleanedTitle)
    case .bound, .folder:
      let newRelativePath = try await libraryService.renameFolder(at: relativePath, with: cleanedTitle)
      cacheKey = newRelativePath
      syncService.scheduleRenameFolder(at: relativePath, name: cleanedTitle)
    }

    return cacheKey
  }

  /// Update the item's author if necessary
  func updateAuthor(_ newAuthor: String, relativePath: String) async {
    let cleanedAuthor = newAuthor.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !cleanedAuthor.isEmpty else { return }

    let storedDetails = libraryService.getItemProperty(
      #keyPath(LibraryItem.details),
      relativePath: relativePath
    ) as? String

    guard storedDetails != cleanedAuthor else { return }

    await libraryService.updateDetails(at: relativePath, details: cleanedAuthor)
  }

  private func sendEvent(_ event: ItemDetailsViewModel.Events) {
    eventsPublisher.send(event)
  }
}
