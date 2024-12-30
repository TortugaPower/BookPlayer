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

enum JellyfinLibraryLevelData: Equatable {
  case topLevel(libraryName: String, userID: String)
  case folder(data: JellyfinLibraryItem)
}

protocol JellyfinLibraryViewModelProtocol: ObservableObject {
  associatedtype DetailsVM: JellyfinAudiobookDetailsViewModelProtocol
  
  var data: JellyfinLibraryLevelData { get }
  var items: [JellyfinLibraryItem] { get set }

  func createFolderViewFor(item: JellyfinLibraryItem) -> JellyfinLibraryView<Self>
  func createAudiobookDetailsViewFor(item: JellyfinLibraryItem) -> JellyfinAudiobookDetailsView<DetailsVM, Self>

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem)
  func cancelFetchItems()

  func createItemImageURL(_ item: JellyfinLibraryItem, size: CGSize?) -> URL?
  @MainActor
  func beginDownloadAudiobook(_ item: JellyfinLibraryItem)
  
  @MainActor
  func handleDoneAction()
}

final class JellyfinLibraryViewModel: JellyfinLibraryViewModelProtocol, BPLogger {
  enum Routes {
    case done
    case showAlert(content: BPAlertContent)
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

  func createFolderViewFor(item: JellyfinLibraryItem) -> JellyfinLibraryView<JellyfinLibraryViewModel> {
    let data = JellyfinLibraryLevelData.folder(data: item)
    let vm = JellyfinLibraryViewModel(data: data, apiClient: apiClient, singleFileDownloadService: singleFileDownloadService)
    vm.onTransition = self.onTransition
    return JellyfinLibraryView(viewModel: vm)
  }
  
  func createAudiobookDetailsViewFor(item: JellyfinLibraryItem) -> JellyfinAudiobookDetailsView<JellyfinAudiobookDetailsViewModel, JellyfinLibraryViewModel> {
    let vm = JellyfinAudiobookDetailsViewModel(item: item, apiClient: apiClient)
    vm.onTransition = { [weak self] route in
      switch route {
      case .showAlert(let content): self?.onTransition?(.showAlert(content: content))
      }
    }
    return JellyfinAudiobookDetailsView(viewModel: vm)
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
      do {
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
      } catch is CancellationError {
        // ignore
      } catch {
        Task { @MainActor in
          self.showErrorAlert(message: error.localizedDescription)
        }
      }
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
      
      do {
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
      } catch is CancellationError {
        // ignore
      } catch {
        Task { @MainActor in
          self.showErrorAlert(message: error.localizedDescription)
        }
      }
    }
  }
  
  func createItemImageURL(_ item: JellyfinLibraryItem, size: CGSize?) -> URL? {
    do {
      return try createItemImageURLInternal(item, size: size)
    } catch {
      Self.logger.error("Failed to create item image URL (item ID: \(item.id), kind: \(String(reflecting: item.kind)), error: \(error))")
      return nil
    }
  }

  private func createItemImageURLInternal(_ item: JellyfinLibraryItem, size: CGSize?) throws(JellyfinError) -> URL {
    var parameters = Paths.GetItemImageParameters()
    if let size {
      parameters.fillWidth = Int(size.width)
      parameters.fillHeight = Int(size.height)
    }

    let request = Paths.getItemImage(itemID: item.id, imageType: "Primary", parameters: parameters)
    let components = try createUrlComponentsForApiRequest(request)

    guard let url = components.url else {
      throw .urlFromComponents(components)
    }
    return url
  }

  func createItemDownloadUrl(_ item: JellyfinLibraryItem) throws(JellyfinError) -> URL {
    let request = Paths.getDownload(itemID: item.id)
    var components = try createUrlComponentsForApiRequest(request)

    var queryItems = components.queryItems ?? []
    queryItems.append(URLQueryItem(name: "api_key", value: apiClient.accessToken))
    components.queryItems = queryItems

    guard let url = components.url else {
      let error = JellyfinError.urlFromComponents(components)
      Self.logger.error("Failed to build URL from components: \(components)")
      throw error
    }
    return url
  }

  private func createUrlComponentsForApiRequest<Response>(_ request: Request<Response>) throws(JellyfinError) -> URLComponents {
    guard let requestUrl = request.url else {
      throw .urlMalformed(nil)
    }
    let requestAbsoluteUrl = requestUrl.scheme == nil ? apiClient.configuration.url.appendingPathComponent(requestUrl.absoluteString) : requestUrl

    guard var components = URLComponents(url: requestAbsoluteUrl, resolvingAgainstBaseURL: false) else {
      throw .urlMalformed(requestUrl)
    }
    if let query = request.query, !query.isEmpty {
        components.queryItems = query.map(URLQueryItem.init)
    }
    return components
  }

  @MainActor
  func beginDownloadAudiobook(_ item: JellyfinLibraryItem) {
    do {
      let url = try createItemDownloadUrl(item)
      singleFileDownloadService.handleDownload(url)
    } catch {
      showErrorAlert(message: error.localizedDescription)
    }
  }
  
  @MainActor
  func handleDoneAction() {
    onTransition?(.done)
  }
  
  @MainActor
  private func showErrorAlert(message: String) {
    self.onTransition?(.showAlert(content: BPAlertContent.errorAlert(message: message)))
  }
}
