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

  let reloadCenter: ListReloadCenter

  private var hardcoverBook: SimpleHardcoverBook?

  /// File name
  @Published var originalFileName: String
  /// Title of the item
  @Published var title: String
  /// Author of the item (only applies for books)
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
  var showAuthor: Bool { item.type == .book }

  @Published var hardcoverSectionViewModel: ItemDetailsHardcoverSectionView.Model?

  init(
    item: SimpleLibraryItem,
    libraryService: LibraryService,
    syncService: SyncService,
    hardcoverService: HardcoverServiceProtocol,
    reloadCenter: ListReloadCenter
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
    self.reloadCenter = reloadCenter
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
      if let item = await libraryService.getHardcoverBook(for: item.relativePath) {
        hardcoverBook = item
        hardcoverSectionViewModel?.pickerViewModel.selected = .init(
          id: item.id,
          artworkURL: item.artworkURL,
          title: item.title,
          author: item.author
        )
      }
    }
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
        reloadCenter.reload(.path(item.parentFolder ?? ""))
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
      syncService.scheduleUploadArtwork(relativePath: cacheKey)

      loadingState.show = false
      reloadCenter.reload(.path(item.parentFolder ?? ""))
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
