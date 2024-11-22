//
//  JellyfinLibraryViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-27.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import Get
import JellyfinAPI
import BookPlayerKit

enum JellyfinLibraryLevelData {
  case topLevel(libraryName: String, userID: String)
  case folder(data: JellyfinLibraryItem)
}

protocol JellyfinLibraryViewModelProtocol: ObservableObject {
  associatedtype FolderViewModel: JellyfinLibraryViewModelProtocol

  var data: JellyfinLibraryLevelData { get }
  var items: [JellyfinLibraryItem] { get set }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> FolderViewModel

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem)
  func cancelFetchItems()

  func createItemImageURL(_ item: JellyfinLibraryItem, size: CGSize?) -> URL?

  func beginDownloadAudiobook(_ item: JellyfinLibraryItem)
  
  @MainActor
  func handleDoneAction()
}

class JellyfinLibraryViewModel: JellyfinLibraryViewModelProtocol {
  enum Routes {
    case done
  }
  
  let data: JellyfinLibraryLevelData
  @Published var items: [JellyfinLibraryItem] = []

  var onTransition: BPTransition<Routes>?

  private var apiClient: JellyfinClient
  private var singleFileDownloadService: SingleFileDownloadService
  private var fetchTask: Task<(), any Error>?
  private var nextStartItemIndex = 0
  private var maxNumItems: Int?

  private static let itemBatchSize = 20
  private static let itemFetchMargin = 3

  var canFetchMoreItems: Bool {
    return maxNumItems == nil || nextStartItemIndex < maxNumItems!
  }

  init(data: JellyfinLibraryLevelData, apiClient: JellyfinClient, singleFileDownloadService: SingleFileDownloadService) {
    self.data = data
    self.apiClient = apiClient
    self.singleFileDownloadService = singleFileDownloadService
  }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> JellyfinLibraryViewModel {
    let data = JellyfinLibraryLevelData.folder(data: item)
    let vm = JellyfinLibraryViewModel(data: data, apiClient: apiClient, singleFileDownloadService: singleFileDownloadService)
    vm.onTransition = self.onTransition
    return vm
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

    switch data {
    case .topLevel(libraryName: _, userID: let userID):
      fetchTopLevelItems(userID: userID)
    case .folder(data: let data):
      fetchFolderItems(folderID: data.id)
    }
  }
  
  private func fetchTopLevelItems(userID: String) {
    items = []
    
    let parameters = Paths.GetUserViewsParameters(userID: userID)

    fetchTask?.cancel()
    fetchTask = Task {
      let response = try await apiClient.send(Paths.getUserViews(parameters: parameters))
      try Task.checkCancellation()
      let userViews = (response.value.items ?? [])
        .compactMap { userView -> JellyfinLibraryItem? in
          guard userView.collectionType == .books else {
            return nil
          }
          return JellyfinLibraryItem(apiItem: userView)
        }
      await { @MainActor in
        self.items = userViews
      }()
    }
  }
  
  private func fetchFolderItems(folderID: String) {
    let parameters = Paths.GetItemsParameters(
      startIndex: nextStartItemIndex,
      limit: Self.itemBatchSize,
      isRecursive: false,
      sortOrder: [.ascending],
      parentID: folderID,
      fields: [.sortName],
      includeItemTypes: [.audioBook, .folder],
      sortBy: [.isFolder, .sortName],
      imageTypeLimit: 1
    )

    fetchTask = Task {
      defer { self.fetchTask = nil }

      let response = try await apiClient.send(Paths.getItems(parameters: parameters))
      try Task.checkCancellation()

      let nextStartItemIndex = if let startIndex = response.value.startIndex, let numItems = response.value.items?.count {
        startIndex + numItems
      } else {
        -1
      }
      let maxNumItems = response.value.totalRecordCount ?? 0

      let items = (response.value.items ?? [])
        .filter { item in item.id != nil }
        .compactMap { item -> JellyfinLibraryItem? in
          return JellyfinLibraryItem(apiItem: item)
        }

      await { @MainActor in
        self.nextStartItemIndex = max(self.nextStartItemIndex, nextStartItemIndex)
        self.maxNumItems = maxNumItems
        self.items.append(contentsOf: items)
      }()
    }
  }

  func createItemImageURL(_ item: JellyfinLibraryItem, size: CGSize?) -> URL? {
    var parameters = Paths.GetItemImageParameters()
    if let size {
      parameters.fillWidth = Int(size.width)
      parameters.fillHeight = Int(size.height)
    }

    let request = Paths.getItemImage(itemID: item.id, imageType: "Primary", parameters: parameters)
    guard let components = createUrlComponentsForApiRequest(request) else {
      return nil
    }
    return components.url
  }

  func createItemDownloadUrl(_ item: JellyfinLibraryItem) -> URL? {
    let request = Paths.getDownload(itemID: item.id)
    guard var components = createUrlComponentsForApiRequest(request) else {
      return nil
    }

    var queryItems = components.queryItems ?? []
    queryItems.append(URLQueryItem(name: "api_key", value: apiClient.accessToken))
    components.queryItems = queryItems

    return components.url
  }

  private func createUrlComponentsForApiRequest<Response>(_ request: Request<Response>) -> URLComponents? {
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
    return components
  }

  func beginDownloadAudiobook(_ item: JellyfinLibraryItem) {
    guard let url = createItemDownloadUrl(item) else {
      return
    }
    singleFileDownloadService.handleDownload(url)
  }
  
  @MainActor
  func handleDoneAction() {
    onTransition?(.done)
  }
}
