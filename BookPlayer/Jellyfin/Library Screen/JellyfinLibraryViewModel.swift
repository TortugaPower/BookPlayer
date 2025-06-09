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
  var items: [JellyfinLibraryItem] { get set }
  var layoutStyle: JellyfinLayoutOptions { get set }
  var connectionService: JellyfinConnectionService { get }
  var error: Error? { get set }

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem)
  func cancelFetchItems()

  @MainActor
  func handleDoneAction()
}

enum JellyfinLayoutOptions: String {
  case grid, list
}

final class JellyfinLibraryViewModel: JellyfinLibraryViewModelProtocol, BPLogger {
  enum Routes {
    case done
  }

  var navigation: BPNavigation
  let navigationTitle: String
  @Published var layoutStyle = JellyfinLayoutOptions.grid
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
    return maxNumItems == nil || nextStartItemIndex < maxNumItems!
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
    items = []

    fetchTask?.cancel()
    fetchTask = Task {
      do {
        let userViews = try await connectionService.fetchTopLevelItems()

        await { @MainActor in
          self.items = userViews
        }()
      } catch is CancellationError {
        // ignore
      } catch {
        Task { @MainActor in
          self.error = error
        }
      }
    }
  }

  private func fetchFolderItems(folderID: String) {
    fetchTask = Task {
      defer { self.fetchTask = nil }

      do {
        let (items, nextStartItemIndex, maxNumItems) = try await connectionService.fetchItems(
          in: folderID,
          startIndex: nextStartItemIndex,
          limit: Self.itemBatchSize
        )

        await { @MainActor in
          self.nextStartItemIndex = max(self.nextStartItemIndex, nextStartItemIndex)
          self.maxNumItems = maxNumItems
          self.items.append(contentsOf: items)
        }()
      } catch is CancellationError {
        // ignore
      } catch {
        Task { @MainActor in
          self.error = error
        }
      }
    }
  }

  @MainActor
  func handleDoneAction() {
    onTransition?(.done)
  }
}
