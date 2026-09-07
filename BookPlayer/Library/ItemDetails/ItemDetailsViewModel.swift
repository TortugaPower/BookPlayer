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
  /// Guards `load()` so a re-appear doesn't refetch. Meaningful only because the view owns
  /// this model with @StateObject — under the old per-render recreation it would have been
  /// wiped along with the instance.
  private var didLoad = false

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
  /// Host display strings for the external-resources section, keyed by providerId.
  /// Resolved off the main thread (keychain read + JSON decode per provider) — the
  /// section view just renders this map.
  @Published private(set) var resolvedExternalHosts: [String: String] = [:]

  init(
    item: SimpleLibraryItem,
    // The protocol types the stored properties already use: the concrete ones here were
    // the last thing keeping this model out of a test, since no mock could be injected.
    libraryService: LibraryServiceProtocol,
    syncService: SyncServiceProtocol,
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

  }

  /// Populate what has to be fetched. Driven by the view's `.task` rather than `init` so
  /// SwiftUI owns the lifetime: the work is cancelled on dismissal — a hardcover fetch can
  /// no longer land its stub repair after the sheet is gone — and a test can await it
  /// instead of racing a task that construction started on its own.
  ///
  /// The call site deliberately passes no `id:`. `item` is fixed at construction, so nothing
  /// should re-trigger this, and keying on the model's ObjectIdentifier would re-fire the
  /// whole load every time the model were recreated.
  @MainActor
  func load() async {
    guard !didLoad else { return }
    didLoad = true

    // Hosts first: it is a local keychain read feeding a row that has no loading state,
    // while the hardcover path can await a network fetch (and shows a spinner for it) —
    // the reverse order left the host field waiting on it.
    await resolveExternalHosts()
    await resolveHardcoverSelection()

    // A load cancelled midway (sheet dismissed during the fetch) has to stay retryable, or
    // re-presenting the screen would skip it and leave the rows half-populated.
    if Task.isCancelled {
      didLoad = false
    }
  }

  /// The resources the external-resources section renders: media-server links only, since
  /// Hardcover has its own section with a book picker right above it.
  var hostedExternalResources: [SimpleExternalResource] {
    item.externalResources?.mediaServerResources ?? []
  }

  private func resolveExternalHosts() async {
    let resources = hostedExternalResources
    guard !resources.isEmpty else { return }
    // Off-main: the section view used to do these reads synchronously on appear
    let resolved = await Task.detached(priority: .utility) {
      IntegrationHostResolver.hostDisplayStrings(for: resources, keychain: KeychainService())
    }.value
    await MainActor.run { resolvedExternalHosts = resolved }
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
