//
//  ItemDetailsViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 5/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

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
  /// Hardcover service for managing assignments
  let hardcoverService: HardcoverServiceProtocol
  /// View model for the SwiftUI form
  let formViewModel: ItemDetailsFormViewModel
  /// Callback to handle actions on this screen
  public var onTransition: BPTransition<Routes>?

  private var eventsPublisher = InterfaceUpdater<ItemDetailsViewModel.Events>()

  private var hardcoverBook: SimpleHardcoverBook?
  private var disposeBag = Set<AnyCancellable>()

  /// Initializer
  init(
    item: SimpleLibraryItem,
    hardcoverService: HardcoverServiceProtocol,
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol
  ) {
    self.item = item
    self.libraryService = libraryService
    self.syncService = syncService
    self.hardcoverService = hardcoverService
    /// Xcode Cloud is throwing an error on #keyPath(BookPlayerKit.LibraryItem.lastPlayDate)
    let lastPlayedDate =
      libraryService.getItemProperty(
        "lastPlayDate",
        relativePath: item.relativePath
      ) as? Date
    self.formViewModel = ItemDetailsFormViewModel(
      item: item,
      lastPlayedDate: lastPlayedDate,
      hardcoverService: hardcoverService
    )

    loadHardcoverBook()
  }

  func observeEvents() -> AnyPublisher<ItemDetailsViewModel.Events, Never> {
    eventsPublisher.eraseToAnyPublisher()
  }

  func loadHardcoverBook() {
    Task {
      if let item = await libraryService.getHardcoverBook(for: item.relativePath) {
        hardcoverBook = item
        formViewModel.hardcoverSectionViewModel?.pickerViewModel.selected = .init(
          id: item.id,
          artworkURL: item.artworkURL,
          title: item.title,
          author: item.author
        )
      }
    }
  }

  func handleCancelAction() {
    onTransition?(.cancel)
  }

  func handleSaveAction() {
    Task { @MainActor [weak self] in
      guard let self = self else { return }

      self.sendEvent(.showLoader(flag: true))

      let cacheKey: String

      do {
        cacheKey = try updateTitle(formViewModel.title, relativePath: item.relativePath)
      } catch {
        self.sendEvent(.showLoader(flag: false))
        sendEvent(.showAlert(content: BPAlertContent.errorAlert(message: error.localizedDescription)))
        return
      }

      if formViewModel.showAuthor {
        updateAuthor(formViewModel.author, relativePath: item.relativePath)
      }

      if let pickerViewModel = formViewModel.hardcoverSectionViewModel?.pickerViewModel,
        pickerViewModel.selected?.id != hardcoverBook?.id
      {

        if let currentBook = hardcoverBook, currentBook.userBookID != nil {
          self.sendEvent(.showLoader(flag: false))
          showHardcoverRemovalConfirmation(for: currentBook, newSelection: pickerViewModel.selected)
          return
        }

        await assignNewSelection(pickerViewModel.selected)
      }

      guard formViewModel.artworkIsUpdated else {
        self.sendEvent(.showLoader(flag: false))
        onTransition?(.done)
        return
      }

      guard let imageData = formViewModel.selectedImage?.jpegData(compressionQuality: 0.3) else {
        self.sendEvent(.showLoader(flag: false))
        sendEvent(.showAlert(content: BPAlertContent.errorAlert(message: "Failed to process artwork")))
        return
      }

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

    let storedTitle =
      libraryService.getItemProperty(
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

    let storedDetails =
      libraryService.getItemProperty(
        #keyPath(LibraryItem.details),
        relativePath: relativePath
      ) as? String

    guard storedDetails != cleanedAuthor else { return }

    libraryService.updateDetails(at: relativePath, details: cleanedAuthor)
  }

  private func sendEvent(_ event: ItemDetailsViewModel.Events) {
    eventsPublisher.send(event)
  }

  private func showHardcoverRemovalConfirmation(for book: SimpleHardcoverBook, newSelection: HardcoverBookRow.Model?) {
    let keepItAction = BPActionItem(
      title: "hardcover_remove_keep_it".localized,
      style: .default
    ) { [weak self] in
      Task { [weak self] in
        await self?.assignNewSelection(newSelection)
        self?.handleSaveAction()
      }
    }

    let removeItAction = BPActionItem(
      title: "hardcover_remove_remove_it".localized,
      style: .destructive
    ) { [weak self] in
      guard let self = self else { return }

      Task { @MainActor [weak self] in
        guard let self = self else { return }

        do {
          try await self.hardcoverService.removeFromLibrary(book)
          await self.assignNewSelection(newSelection)
          self.handleSaveAction()
        } catch {
          self.sendEvent(.showAlert(content: BPAlertContent.errorAlert(message: error.localizedDescription)))
        }
      }
    }

    let message = String(format: "hardcover_remove_confirmation_message".localized, book.title, book.author)

    let alertContent = BPAlertContent(
      title: "hardcover_remove_confirmation_title".localized,
      message: message,
      style: .alert,
      actionItems: [keepItAction, removeItAction]
    )

    sendEvent(.showAlert(content: alertContent))
  }

  private func assignNewSelection(
    _ newSelection: HardcoverBookRow.Model?
  ) async {
    if let selected = newSelection {
      let book = SimpleHardcoverBook(
        id: selected.id,
        artworkURL: selected.artworkURL,
        title: selected.title,
        author: selected.author,
        status: .local,
        userBookID: nil
      )
      await hardcoverService.assignItem(book, to: item)
      hardcoverBook = book
    } else {
      await hardcoverService.assignItem(nil, to: item)
      hardcoverBook = nil
    }
  }
}
