//
//  JellyfinLibraryViewModel.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import JellyfinAPI

struct JellyfinLibraryUserViewData: Identifiable, Hashable {
  let id: String
  let name: String
}

struct JellyfinLibraryItem: Identifiable, Hashable {
  let id: String
  let name: String
}

protocol JellyfinLibraryViewModelProtocol: ObservableObject {
  typealias UserView = JellyfinLibraryUserViewData
  typealias Item = JellyfinLibraryItem

  var userViews: [UserView] { get set }
  var selectedView: UserView? { get set }
  var items: [Item] { get set }

  func fetchMoreItemsIfNeeded(currentItem: Item)
}

class JellyfinLibraryViewModel: ViewModelProtocol, JellyfinLibraryViewModelProtocol {
  typealias UserView = JellyfinLibraryUserViewData
  typealias Item = JellyfinLibraryItem

  weak var coordinator: JellyfinCoordinator!

  @Published var userViews: [UserView] = []
  @Published var selectedView: UserView? {
    didSet {
      self.items = []
      self.itemsLoadTask?.cancel()
      self.itemsLoadTask = nil
      self.nextStartItemIndex = 0
      self.maxNumItems = nil
      self.fetchMoreItems()
    }
  }
  @Published var items: [Item] = []
  private var apiClient: JellyfinClient!
  private var itemsLoadTask: Task<(), any Error>?
  private var nextStartItemIndex = 0
  private var maxNumItems: Int?

  private static let itemBatchSize = 20
  private static let itemFetchMargin = 3

  var canLoadMoreItems: Bool {
    if selectedView == nil {
      return false
    }
    return maxNumItems == nil || nextStartItemIndex < maxNumItems!
  }

  init() {
  }

  init(apiClient: JellyfinClient) {
    self.apiClient = apiClient

    self.fetchMoreItems()
  }

  func fetchMoreItemsIfNeeded(currentItem: Item) {
    let thresholdIndex = items.index(items.endIndex, offsetBy: -JellyfinLibraryViewModel.itemFetchMargin)
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
      limit: JellyfinLibraryViewModel.itemBatchSize,
      isRecursive: true,
      parentID: self.selectedView!.id,
      includeItemTypes: [.audioBook]
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
        .map { item in JellyfinLibraryViewModel.Item(id: item.id!, name: item.name ?? item.id!) }

      await { @MainActor in
        self.nextStartItemIndex = max(self.nextStartItemIndex, nextStartItemIndex)
        self.maxNumItems = maxNumItems
        self.items.append(contentsOf: items)
      }()
    }
  }
}
