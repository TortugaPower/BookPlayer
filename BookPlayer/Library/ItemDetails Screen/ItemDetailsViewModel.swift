//
//  ItemDetailsViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 5/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import Foundation
import BookPlayerKit
import Combine

class ItemDetailsViewModel: ViewModelProtocol {
  /// Possible routes for the screen
  enum Routes {
    case cancel
    case done
  }

  enum Events {
    case showAlert(content: BPAlertContent)
    case showLoader(flag: Bool)
  }

  weak var coordinator: ItemListCoordinator!

  /// Item being modified
  let item: SimpleLibraryItem
  /// Library service used for modifications
  let libraryService: LibraryServiceProtocol
  /// Service to sync new artwork
  let syncService: SyncServiceProtocol
  /// View model for the SwiftUI form
  let formViewModel: ItemDetailsFormViewModel
  /// Callback to handle actions on this screen
  public var onTransition: BPTransition<Routes>?

  private var eventsPublisher = InterfaceUpdater<ItemDetailsViewModel.Events>()

  private let hardcoverItem: SimpleHardcoverItem?
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
    /// Xcode Cloud is throwing an error on #keyPath(BookPlayerKit.LibraryItem.lastPlayDate)
    let lastPlayedDate = libraryService.getItemProperty(
      "lastPlayDate",
      relativePath: item.relativePath
    ) as? Date
    self.formViewModel = ItemDetailsFormViewModel(
      item: item,
      lastPlayedDate: lastPlayedDate
    )

    if let item = libraryService.getHardcoverItem(for: item.relativePath) {
      hardcoverItem = item
      formViewModel.hardcoverSectionViewModel?.pickerViewModel.selected = .init(
        id: item.id,
        artworkURL: item.artworkURL,
        title: item.title,
        author: item.author
      )
    } else {
      hardcoverItem = nil
    }
  }

  func observeEvents() -> AnyPublisher<ItemDetailsViewModel.Events, Never> {
    eventsPublisher.eraseToAnyPublisher()
  }

  func handleCancelAction() {
    onTransition?(.cancel)
  }

  func handleSaveAction() {
    let cacheKey: String

    do {
      cacheKey = try updateTitle(formViewModel.title, relativePath: item.relativePath)
    } catch {
      sendEvent(.showAlert(content: BPAlertContent.errorAlert(message: error.localizedDescription)))
      return
    }

    if formViewModel.showAuthor {
      updateAuthor(formViewModel.author, relativePath: item.relativePath)
    }

    if let pickerViewModel = formViewModel.hardcoverSectionViewModel?.pickerViewModel,
       pickerViewModel.selected?.id != hardcoverItem?.id {
      if let selected = pickerViewModel.selected {
        let hardcoverItem = SimpleHardcoverItem(
          id: selected.id,
          artworkURL: selected.artworkURL,
          title: selected.title,
          author: selected.author,
          status: .local
        )
        libraryService.setHardcoverItem(hardcoverItem, for: item.relativePath)
      } else {
        libraryService.setHardcoverItem(nil, for: item.relativePath)
      }
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

      await ArtworkService.removeCache(for: item.relativePath)
      await ArtworkService.storeInCache(imageData, for: cacheKey)
      self.syncService.scheduleUploadArtwork(relativePath: cacheKey)

      self.sendEvent(.showLoader(flag: false))
      self.onTransition?(.done)
    }
  }

  /// Update the item title if necessary
  /// - Returns: The new relative path to be used as the cache key
  func updateTitle(_ newTitle: String, relativePath: String) throws -> String {
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
      libraryService.renameBook(at: relativePath, with: cleanedTitle)
    case .bound, .folder:
      let newRelativePath = try libraryService.renameFolder(at: relativePath, with: cleanedTitle)
      cacheKey = newRelativePath
      syncService.scheduleRenameFolder(at: relativePath, name: cleanedTitle)
    }

    return cacheKey
  }

  /// Update the item's author if necessary
  func updateAuthor(_ newAuthor: String, relativePath: String) {
    let cleanedAuthor = newAuthor.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !cleanedAuthor.isEmpty else { return }

    let storedDetails = libraryService.getItemProperty(
      #keyPath(LibraryItem.details),
      relativePath: relativePath
    ) as? String

    guard storedDetails != cleanedAuthor else { return }

    libraryService.updateDetails(at: relativePath, details: cleanedAuthor)
  }

  private func sendEvent(_ event: ItemDetailsViewModel.Events) {
    eventsPublisher.send(event)
  }
}
