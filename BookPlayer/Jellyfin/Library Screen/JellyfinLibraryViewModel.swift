//
//  JellyfinLibraryViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-27.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
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
  var connectionService: JellyfinConnectionService { get }
  var error: Error? { get set }

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem)
  func cancelFetchItems()

  @MainActor
  func handleDoneAction()
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
  @Published var error: Error?

  var onTransition: BPTransition<Routes>?

  let folderID: String?
  let connectionService: JellyfinConnectionService
  private var fetchTask: Task<(), any Error>?
  private var nextStartItemIndex = 0
  private var maxNumItems: Int?

  private static let itemBatchSize = 20
  private static let itemFetchMargin = 3

  var canFetchMoreItems: Bool {
    maxNumItems == nil || nextStartItemIndex < maxNumItems!
  }

  init(
    folderID: String?,
    connectionService: JellyfinConnectionService,
    navigation: BPNavigation,
    navigationTitle: String
  ) {
    self.folderID = folderID
    self.connectionService = connectionService
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
        self.maxNumItems = maxNumItems
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
}
