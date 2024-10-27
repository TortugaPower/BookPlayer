//
//  JellyfinLibraryFolderViewModel.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-27.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import JellyfinAPI

protocol JellyfinLibraryFolderViewModelProtocol: ObservableObject {
  typealias Item = JellyfinLibraryItem
  associatedtype FolderViewModel: JellyfinLibraryFolderViewModelProtocol

  var data: Item { get }
  var items: [Item] { get set }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> FolderViewModel

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: Item)
}

class JellyfinLibraryFolderViewModel: JellyfinLibraryFolderViewModelProtocol {
  let data: Item
  @Published var items: [Item] = []

  private var apiClient: JellyfinClient!
  private var itemsLoadTask: Task<(), any Error>?
  private var nextStartItemIndex = 0
  private var maxNumItems: Int?

  private static let itemBatchSize = 20
  private static let itemFetchMargin = 3

  var canLoadMoreItems: Bool {
    return maxNumItems == nil || nextStartItemIndex < maxNumItems!
  }

  init(data: Item, apiClient: JellyfinClient) {
    self.data = data
    self.apiClient = apiClient
  }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> JellyfinLibraryFolderViewModel {
    return JellyfinLibraryFolderViewModel(data: item, apiClient: apiClient)
  }

  func fetchInitialItems() {
    fetchMoreItems()
  }

  func fetchMoreItemsIfNeeded(currentItem: Item) {
    let thresholdIndex = items.index(items.endIndex, offsetBy: -Self.itemFetchMargin)
    if items.firstIndex(where: { $0.id == currentItem.id }) == thresholdIndex {
      fetchMoreItems()
    }
  }

  private func fetchMoreItems() {
    guard itemsLoadTask == nil && canLoadMoreItems else {
      return
    }

    let parameters = Paths.GetItemsParameters(
      startIndex: nextStartItemIndex,
      limit: Self.itemBatchSize,
      isRecursive: false,
      sortOrder: [.ascending],
      parentID: data.id,
      fields: [.sortName],
      includeItemTypes: [.audioBook, .folder],
      sortBy: [.isFolder, .sortName]
    )

    itemsLoadTask = Task {
      defer { self.itemsLoadTask = nil }

      let response = try await apiClient.send(Paths.getItems(parameters: parameters))

      let nextStartItemIndex = if let startIndex = response.value.startIndex, let numItems = response.value.items?.count {
        startIndex + numItems
      } else {
        -1
      }
      let maxNumItems = response.value.totalRecordCount ?? 0

      let items = (response.value.items ?? [])
        .filter { item in item.id != nil }
        .compactMap { item -> Item? in
          let kind: Item.Kind? = switch item.type {
          case .audioBook: .audiobook
          case .folder: .folder
          default: nil
          }

          guard let id = item.id, let kind else {
            return nil
          }
          return JellyfinLibraryItem(id: id, name: item.name ?? id, kind: kind)
        }

      await { @MainActor in
        self.nextStartItemIndex = max(self.nextStartItemIndex, nextStartItemIndex)
        self.maxNumItems = maxNumItems
        self.items.append(contentsOf: items)
      }()
    }
  }
}
