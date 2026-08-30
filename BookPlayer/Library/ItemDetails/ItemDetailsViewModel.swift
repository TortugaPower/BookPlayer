//
//  ItemDetailsViewModel.swift
//  BookPlayer
//
//  Created by gianni.carlo on 20/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import UIKit

final class ItemDetailsViewModel: ObservableObject {
  struct HardcoverAlertPayload: Identifiable {
    var id = UUID()
    let book: SimpleHardcoverBook
    let newSelection: HardcoverBookRow.Model?
  }

  @Published var showHardcoverRemovalAlert = false
  @Published var hardcoverAlertPayload: HardcoverAlertPayload?

  /// Item being modified
  let item: SimpleLibraryItem
  /// Library service used for modifications
  let libraryService: LibraryServiceProtocol
  /// Service to sync new artwork
  let syncService: SyncServiceProtocol
  /// Hardcover service for managing assignments
  let hardcoverService: HardcoverServiceProtocol

  let listState: ListStateManager

  private var hardcoverBook: SimpleHardcoverBook?

  /// File name
  @Published var originalFileName: String
  /// Title of the item
  @Published var title: String
  /// Author of the item (applies for books and volumes)
  @Published var author: String
  /// Artwork image
  @Published var selectedImage: UIImage?
  /// Last played date
  let lastPlayedDate: String?
  /// Original item title
  var titlePlaceholder: String { item.title }
  /// Original item author
  var authorPlaceholder: String { item.details }

  var progress: Double { item.progress }
  /// Determines if there's an update for the artwork
  var artworkIsUpdated: Bool = false
  /// Flag to show the author field
  var showAuthor: Bool { item.type != .folder }

  @Published var hardcoverSectionViewModel: ItemDetailsHardcoverSectionView.Model?

  init(
    item: SimpleLibraryItem,
    libraryService: LibraryService,
    syncService: SyncService,
    hardcoverService: HardcoverServiceProtocol,
    listState: ListStateManager
  ) {
    let cachedImageURL = ArtworkService.getCachedImageURL(for: item.relativePath)

    /// Xcode Cloud is throwing an error on #keyPath(BookPlayerKit.LibraryItem.lastPlayDate)
    let lastPlayedDate =
      libraryService.getItemProperty(
        "lastPlayDate",
        relativePath: item.relativePath
      ) as? Date

    let playedDate: String?
    if let lastPlayedDate {
      let formatter = DateFormatter()
      formatter.timeStyle = .short
      formatter.dateStyle = .medium
      playedDate = formatter.string(from: lastPlayedDate)
    } else {
      playedDate = nil
    }

    self.item = item
    self.libraryService = libraryService
    self.syncService = syncService
    self.hardcoverService = hardcoverService
    self.listState = listState
    self.originalFileName = item.originalFileName
    self.title = item.title
    self.author = item.details
    self.selectedImage = UIImage(contentsOfFile: cachedImageURL.path)
    self.lastPlayedDate = playedDate

    hardcoverSectionViewModel = ItemDetailsHardcoverSectionViewModel(
      item: item,
      hardcoverService: hardcoverService
    )

    Task {
      await resolveHardcoverSelection()
    }
  }

  /// Populate the Hardcover picker selection. Prefers the full local reference; otherwise
  /// falls back to the hardcover external resource — showing the item's title right away,
  /// then fetching the real book info from Hardcover by its providerId.
  @MainActor
  private func resolveHardcoverSelection() async {
    let stored = await libraryService.getHardcoverBook(for: item.relativePath)
    // Only a row WITH metadata short-circuits: updateHardcoverStatus persists a
    // status-only stub (empty title) when a synced-down link crosses the reading
    // threshold before this device ever opened details — that stub must not shadow
    // the fetch-repair below, or the row renders blank forever.
    if let book = stored, !book.title.isEmpty {
      hardcoverBook = book
      hardcoverSectionViewModel?.pickerViewModel.selected = .init(
        id: book.id,
        artworkURL: book.artworkURL,
        title: book.title,
        author: book.author
      )
      return
    }

    /// No full local reference — fall back to the hardcover external resource, if any
    guard hardcoverSectionViewModel != nil else { return }

    let resources = await libraryService.getExternalResources(for: item.relativePath)
    guard
      let resource = resources.first(where: {
        $0.providerName == ExternalResource.ProviderName.hardcover.rawValue
      }),
      let bookID = Int(resource.providerId)
    else { return }

    /// Show at least the item's title so the row reflects a selection. The interim
    /// carries the STUB's monotonic state when one exists — getBook() knows nothing
    /// about user state, and the save flow reads userBookID off this property.
    hardcoverBook = SimpleHardcoverBook(
      id: bookID,
      artworkURL: nil,
      title: item.title,
      author: item.details,
      status: stored?.status ?? .local,
      userBookID: stored?.userBookID
    )
    hardcoverSectionViewModel?.pickerViewModel.selected = .init(
      id: bookID,
      artworkURL: nil,
      title: item.title,
      author: item.details
    )

    /// Fetch the real book info from Hardcover and update the selection
    hardcoverSectionViewModel?.isFetchingBook = true
    let fetched = try? await hardcoverService.getBook(id: bookID)
    hardcoverSectionViewModel?.isFetchingBook = false

    /// Discard the result if the selection was swapped or unlinked while fetching
    guard
      let fetched,
      hardcoverSectionViewModel?.pickerViewModel.selected?.id == bookID
    else { return }

    if let stub = stored {
      // Repair the stub ONCE (metadata from Hardcover, state from the stub) so the
      // row renders correctly everywhere without re-fetching per details visit.
      let merged = stub.repairingMetadata(from: fetched)
      await libraryService.setHardcoverBook(merged, for: item.relativePath)
      hardcoverBook = merged
    } else {
      // Never linked locally: display-only, matching the pre-existing behavior.
      hardcoverBook = fetched
    }
    hardcoverSectionViewModel?.pickerViewModel.selected = .init(
      id: fetched.id,
      artworkURL: fetched.artworkURL,
      title: fetched.title,
      author: fetched.author
    )
  }

  func handleSaveAction(_ loadingState: LoadingOverlayState, success: @escaping () -> Void) {
    Task { @MainActor in
      loadingState.show = true

      let cacheKey: String

      do {
        cacheKey = try updateTitle(title.trimmingCharacters(in: .whitespacesAndNewlines), relativePath: item.relativePath)
      } catch {
        loadingState.show = false
        loadingState.error = error
        return
      }

      if showAuthor {
        updateAuthor(author, relativePath: item.relativePath)
      }

      if let pickerViewModel = hardcoverSectionViewModel?.pickerViewModel,
        pickerViewModel.selected?.id != hardcoverBook?.id
      {

        if let currentBook = hardcoverBook, currentBook.userBookID != nil {
          loadingState.show = false
          hardcoverAlertPayload = .init(
            book: currentBook,
            newSelection: pickerViewModel.selected
          )
          showHardcoverRemovalAlert = true
          return
        }

        await assignNewSelection(pickerViewModel.selected)
      }

      guard artworkIsUpdated else {
        loadingState.show = false
        listState.reload(.path(item.parentFolder ?? ""))
        success()
        return
      }

      guard let imageData = selectedImage?.jpegData(compressionQuality: 0.3) else {
        loadingState.show = false
        loadingState.error = BookPlayerError.runtimeError("Failed to process artwork")
        return
      }

      await ArtworkService.removeCache(for: item.relativePath)
      await ArtworkService.storeInCache(imageData, for: cacheKey)
      syncService.scheduleUploadArtwork(relativePath: cacheKey, uuid: item.uuid)

      loadingState.show = false
      listState.reload(.path(item.parentFolder ?? ""))
      success()
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
        "title",
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
      syncService.scheduleRenameFolder(at: relativePath, name: cleanedTitle, for: item.uuid)
    }

    return cacheKey
  }

  /// Update the item's author if necessary
  func updateAuthor(_ newAuthor: String, relativePath: String) {
    let cleanedAuthor = newAuthor.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !cleanedAuthor.isEmpty else { return }

    let storedDetails =
      libraryService.getItemProperty(
        "title",
        relativePath: relativePath
      ) as? String

    guard storedDetails != cleanedAuthor else { return }

    libraryService.updateDetails(at: relativePath, details: cleanedAuthor)
  }

  func assignNewSelection(
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
