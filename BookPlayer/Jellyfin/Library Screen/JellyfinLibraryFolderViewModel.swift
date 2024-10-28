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
  associatedtype FolderViewModel: JellyfinLibraryFolderViewModelProtocol

  var data: JellyfinLibraryItem { get }
  var items: [JellyfinLibraryItem] { get set }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> FolderViewModel

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem)
  func cancelFetchItems()

  func createItemImageURL(_ item: JellyfinLibraryItem) -> URL?
}

class JellyfinLibraryFolderViewModel: JellyfinLibraryFolderViewModelProtocol {
  let data: JellyfinLibraryItem
  @Published var items: [JellyfinLibraryItem] = []

  private var apiClient: JellyfinClient!
  private var fetchTask: Task<(), any Error>?
  private var nextStartItemIndex = 0
  private var maxNumItems: Int?

  private static let itemBatchSize = 20
  private static let itemFetchMargin = 3

  var canFetchMoreItems: Bool {
    return maxNumItems == nil || nextStartItemIndex < maxNumItems!
  }

  init(data: JellyfinLibraryItem, apiClient: JellyfinClient) {
    self.data = data
    self.apiClient = apiClient
  }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> JellyfinLibraryFolderViewModel {
    return JellyfinLibraryFolderViewModel(data: item, apiClient: apiClient)
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

    let parameters = Paths.GetItemsParameters(
      startIndex: nextStartItemIndex,
      limit: Self.itemBatchSize,
      isRecursive: false,
      sortOrder: [.ascending],
      parentID: data.id,
      fields: [.sortName],
      includeItemTypes: [.audioBook, .folder],
      sortBy: [.isFolder, .sortName],
      imageTypeLimit: 1
    )

    fetchTask = Task {
      defer { self.fetchTask = nil }

      let response = try await apiClient.send(Paths.getItems(parameters: parameters))

      let nextStartItemIndex = if let startIndex = response.value.startIndex, let numItems = response.value.items?.count {
        startIndex + numItems
      } else {
        -1
      }
      let maxNumItems = response.value.totalRecordCount ?? 0

      let items = (response.value.items ?? [])
        .filter { item in item.id != nil }
        .compactMap { item -> JellyfinLibraryItem? in
          let kind: JellyfinLibraryItem.Kind? = switch item.type {
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

  func createItemImageURL(_ item: JellyfinLibraryItem) -> URL? {
    let request = Paths.getItemImage(itemID: item.id, imageType: "Primary")
    guard let requestUrl = request.url else {
      return nil
    }
    let requestAbsoluteUrl = requestUrl.scheme == nil ? apiClient.configuration.url.appendingPathComponent(requestUrl.absoluteString) : requestUrl

    guard var components = URLComponents(url: requestAbsoluteUrl, resolvingAgainstBaseURL: false) else {
      return nil
    }
    if let query = request.query, !query.isEmpty {
        components.queryItems = query.map(URLQueryItem.init)
    }
    return components.url
  }
}
