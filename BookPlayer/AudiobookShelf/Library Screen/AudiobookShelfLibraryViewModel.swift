//
//  AudiobookShelfLibraryViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import SwiftUI

protocol AudiobookShelfLibraryViewModelProtocol: ObservableObject {
  var navigation: BPNavigation { get set }
  var navigationTitle: String { get }
  var layout: AudiobookShelfLayout.Options { get set }
  var sortBy: AudiobookShelfLayout.SortBy { get set }

  var items: [AudiobookShelfLibraryItem] { get set }
  var totalItems: Int { get }
  var error: Error? { get set }

  var editMode: EditMode { get set }
  var selectedItems: Set<AudiobookShelfLibraryItem.ID> { get set }

  var connectionService: AudiobookShelfConnectionService { get }

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: AudiobookShelfLibraryItem)
  func cancelFetchItems()

  @MainActor
  func handleDoneAction()

  @MainActor
  func onEditToggleSelectTapped()
  @MainActor
  func onSelectTapped(for item: AudiobookShelfLibraryItem)
  @MainActor
  func onSelectAllTapped()
  @MainActor
  func onDownloadTapped()
}

enum AudiobookShelfLayout {
  enum Options: String {
    case grid, list
  }

  enum SortBy: String {
    case recent, title
  }
}

final class AudiobookShelfLibraryViewModel: AudiobookShelfLibraryViewModelProtocol, BPLogger {
  enum Routes {
    case done
  }

  var navigation: BPNavigation
  let navigationTitle: String

  @AppStorage(Constants.UserDefaults.audiobookshelfLibraryLayout)
  var layout: AudiobookShelfLayout.Options = .grid

  @AppStorage(Constants.UserDefaults.audiobookshelfLibraryLayoutSortBy)
  var sortBy: AudiobookShelfLayout.SortBy = .recent {
    didSet {
      guard let libraryID = libraryID else { return }
      items = []
      nextPage = 0
      fetchLibraryItems(libraryID: libraryID)
    }
  }

  @Published var items: [AudiobookShelfLibraryItem] = []
  @Published var totalItems = Int.max
  @Published var error: Error?

  @Published var editMode: EditMode = .inactive
  @Published var selectedItems: Set<AudiobookShelfLibraryItem.ID> = []

  var onTransition: BPTransition<Routes>?

  var libraryID: String?
  let connectionService: AudiobookShelfConnectionService
  private let singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?
  private var nextPage = 0

  private static let itemBatchSize = 20
  private static let itemFetchMargin = 3

  private var disposeBag = Set<AnyCancellable>()

  var canFetchMoreItems: Bool {
    items.count < totalItems
  }

  init(
    libraryID: String?,
    connectionService: AudiobookShelfConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    navigation: BPNavigation,
    navigationTitle: String
  ) {
    self.libraryID = libraryID
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.navigation = navigation
    self.navigationTitle = navigationTitle
  }

  func fetchInitialItems() {
    fetchMoreItems()
  }

  func fetchMoreItemsIfNeeded(currentItem: AudiobookShelfLibraryItem) {
    let thresholdIndex = items.index(items.endIndex, offsetBy: -Self.itemFetchMargin)
    if items.firstIndex(where: { $0.id == currentItem.id }) == thresholdIndex {
      fetchMoreItems()
    }
  }

  func cancelFetchItems() {
    fetchTask?.cancel()
    fetchTask = nil
  }

  private func fetchMoreItems() {
    guard fetchTask == nil && canFetchMoreItems else {
      return
    }

    if let libraryID {
      fetchLibraryItems(libraryID: libraryID)
    } else {
      fetchTopLevelItems()
    }
  }

  private func fetchTopLevelItems() {
    fetchTask?.cancel()
    fetchTask = Task { @MainActor in
      items = []

      do {
        let libraries = try await connectionService.fetchLibraries()

        // Convert libraries to library items so users can select which library to browse
        let libraryItems = libraries.map { library in
          AudiobookShelfLibraryItem(
            id: library.id,
            title: library.name,
            kind: .library,
            libraryId: library.id,
            authorName: nil,
            narratorName: nil,
            duration: nil,
            size: nil,
            coverPath: nil,
            progress: nil
          )
        }

        self.totalItems = libraryItems.count
        self.items = libraryItems
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  private func fetchLibraryItems(libraryID: String) {
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }

      do {
        let sortByParam: String
        switch sortBy {
        case .recent:
          sortByParam = "addedAt"
        case .title:
          sortByParam = "media.metadata.title"
        }

        let (items, totalItems) = try await connectionService.fetchItems(
          in: libraryID,
          limit: Self.itemBatchSize,
          page: nextPage,
          sortBy: sortByParam
        )

        self.nextPage += 1
        self.totalItems = totalItems
        self.items.append(contentsOf: items)
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  @MainActor
  func handleDoneAction() {
    onTransition?(.done)
  }

  @MainActor
  func onEditToggleSelectTapped() {
    withAnimation {
      editMode = editMode.isEditing ? .inactive : .active
    }

    if !editMode.isEditing {
      selectedItems.removeAll()
    }
  }

  @MainActor
  func onSelectTapped(for item: AudiobookShelfLibraryItem) {
    if let index = selectedItems.firstIndex(of: item.id) {
      selectedItems.remove(at: index)
    } else {
      selectedItems.insert(item.id)
    }
  }

  @MainActor
  func onSelectAllTapped() {
    if selectedItems.isEmpty {
      let ids: [AudiobookShelfLibraryItem.ID] = items.compactMap { item in
        guard item.kind == .audiobook else { return nil }
        return item.id
      }

      selectedItems = Set(ids)
    } else {
      selectedItems.removeAll()
    }
  }

  @MainActor
  func onDownloadTapped() {
    let items = selectedItems.compactMap({ id in
      self.items.first(where: { $0.id == id })
    })

    var urls = [URL]()
    for item in items {
      do {
        let url = try connectionService.createItemDownloadUrl(item)
        urls.append(url)
      } catch {
        self.error = error
      }
    }
    singleFileDownloadService.handleDownload(urls)
    navigation.dismiss?()
  }
}
