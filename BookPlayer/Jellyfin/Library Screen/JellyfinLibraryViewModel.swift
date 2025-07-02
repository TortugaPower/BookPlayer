//
//  JellyfinLibraryViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-27.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
import Get
import JellyfinAPI
import SwiftUI

enum JellyfinLibraryLevelData: Equatable, Hashable {
  case topLevel(libraryName: String)
  case folder(data: JellyfinLibraryItem)
  case details(data: JellyfinLibraryItem)
}

protocol JellyfinLibraryViewModelProtocol: ObservableObject {
  var navigation: BPNavigation { get set }
  var navigationTitle: String { get }
  var layout: JellyfinLayout.Options { get set }
  var sortBy: JellyfinLayout.SortBy { get set }

  var items: [JellyfinLibraryItem] { get set }
  var totalItems: Int { get }
  var error: Error? { get set }

  var editMode: EditMode { get set }
  var selectedItems: Set<JellyfinLibraryItem.ID> { get set }

  var connectionService: JellyfinConnectionService { get }

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem)
  func cancelFetchItems()

  @MainActor
  func handleDoneAction()

  @MainActor
  func onEditToggleSelectTapped()
  @MainActor
  func onSelectTapped(for item: JellyfinLibraryItem)
  @MainActor
  func onSelectAllTapped()
  @MainActor
  func onDownloadTapped()
}

enum JellyfinLayout {
  enum Options: String {
    case grid, list
  }

  enum SortBy: String {
    case name, smart
  }
}

final class JellyfinLibraryViewModel: JellyfinLibraryViewModelProtocol, BPLogger {
  enum Routes {
    case done
  }

  var navigation: BPNavigation
  let navigationTitle: String

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayout)
  var layout: JellyfinLayout.Options = .grid

  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayoutSortBy)
  var sortBy: JellyfinLayout.SortBy = .smart {
    didSet {
      guard let folderID = folderID else { return }
      items = []
      nextStartItemIndex = 0
      fetchFolderItems(folderID: folderID)
    }
  }

  @Published var items: [JellyfinLibraryItem] = []
  @Published var totalItems = Int.max
  @Published var error: Error?

  @Published var editMode: EditMode = .inactive
  @Published var selectedItems: Set<JellyfinLibraryItem.ID> = []

  var onTransition: BPTransition<Routes>?

  let folderID: String?
  let connectionService: JellyfinConnectionService
  private let singleFileDownloadService: SingleFileDownloadService

  private var fetchTask: Task<(), any Error>?
  private var nextStartItemIndex = 0

  private static let itemBatchSize = 20
  private static let itemFetchMargin = 3

  private var disposeBag = Set<AnyCancellable>()

  var canFetchMoreItems: Bool {
    nextStartItemIndex < totalItems
  }

  init(
    folderID: String?,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService,
    navigation: BPNavigation,
    navigationTitle: String
  ) {
    self.folderID = folderID
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
    self.navigation = navigation
    self.navigationTitle = navigationTitle
  }

  func fetchInitialItems() {
    fetchMoreItems()
  }

  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem) {
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

    if let folderID {
      fetchFolderItems(folderID: folderID)
    } else {
      fetchTopLevelItems()
    }
  }

  private func fetchTopLevelItems() {
    fetchTask?.cancel()
    fetchTask = Task { @MainActor in
      items = []

      do {
        let items = try await connectionService.fetchTopLevelItems()

        self.totalItems = items.count
        self.items = items
      } catch is CancellationError {
        // ignore
      } catch {
        self.error = error
      }
    }
  }

  private func fetchFolderItems(folderID: String) {
    fetchTask = Task { @MainActor in
      defer { self.fetchTask = nil }

      do {
        let (items, nextStartItemIndex, maxNumItems) = try await connectionService.fetchItems(
          in: folderID,
          startIndex: nextStartItemIndex,
          limit: Self.itemBatchSize,
          sortBy: sortBy
        )

        self.nextStartItemIndex = max(self.nextStartItemIndex, nextStartItemIndex)
        self.totalItems = maxNumItems
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
  func onSelectTapped(for item: JellyfinLibraryItem) {
    if let index = selectedItems.firstIndex(of: item.id) {
      selectedItems.remove(at: index)
    } else {
      selectedItems.insert(item.id)
    }
  }

  @MainActor
  func onSelectAllTapped() {
    if selectedItems.isEmpty {
      let ids: [JellyfinLibraryItem.ID] = items.compactMap { item in
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
