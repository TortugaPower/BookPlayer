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
  var layoutStyle: JellyfinLayoutOptions { get set }

  func createFolderViewFor(item: JellyfinLibraryItem) -> JellyfinLibraryView<Self>
  func createAudiobookDetailsViewFor(item: JellyfinLibraryItem) -> JellyfinAudiobookDetailsView<DetailsVM, Self>

  func fetchInitialItems()
  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem)
  func cancelFetchItems()

  func createItemImageURL(_ item: JellyfinLibraryItem, size: CGSize?) -> URL?

  @MainActor
  func handleDoneAction()
}

enum JellyfinLayoutOptions: String {
  case grid, list
}

final class JellyfinLibraryViewModel: JellyfinLibraryViewModelProtocol, BPLogger {
  enum Routes {
    case done
    case showAlert(content: BPAlertContent)
  }

  let data: JellyfinLibraryLevelData
  @Published var layoutStyle = JellyfinLayoutOptions.grid
  @Published var items: [JellyfinLibraryItem] = []

  var onTransition: BPTransition<Routes>?

  private var connectionService: JellyfinConnectionService
  private var singleFileDownloadService: SingleFileDownloadService
  private var fetchTask: Task<(), any Error>?
  private var nextStartItemIndex = 0
  private var maxNumItems: Int?

  private static let itemBatchSize = 20
  private static let itemFetchMargin = 3

  var canFetchMoreItems: Bool {
    return maxNumItems == nil || nextStartItemIndex < maxNumItems!
  }

  init(
    data: JellyfinLibraryLevelData,
    connectionService: JellyfinConnectionService,
    singleFileDownloadService: SingleFileDownloadService
  ) {
    self.data = data
    self.connectionService = connectionService
    self.singleFileDownloadService = singleFileDownloadService
  }

  func createFolderViewFor(item: JellyfinLibraryItem) -> JellyfinLibraryView<JellyfinLibraryViewModel> {
    let data = JellyfinLibraryLevelData.folder(data: item)
    let vm = JellyfinLibraryViewModel(
      data: data,
      connectionService: connectionService,
      singleFileDownloadService: singleFileDownloadService
    )
    vm.onTransition = self.onTransition
    return JellyfinLibraryView(viewModel: vm)
  }

  func createAudiobookDetailsViewFor(
    item: JellyfinLibraryItem
  ) -> JellyfinAudiobookDetailsView<JellyfinAudiobookDetailsViewModel, JellyfinLibraryViewModel> {
    let vm = JellyfinAudiobookDetailsViewModel(
      item: item,
      connectionService: connectionService,
      singleFileDownloadService: singleFileDownloadService
    )
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
    case .topLevel(libraryName: _, let userID):
      fetchTopLevelItems(userID: userID)
    case .folder(let data):
      fetchFolderItems(folderID: data.id)
    }
  }

  private func fetchTopLevelItems(userID: String) {
    items = []

    let parameters = Paths.GetUserViewsParameters(userID: userID)

    fetchTask?.cancel()
    fetchTask = Task {
      do {
        let response = try await connectionService.send(Paths.getUserViews(parameters: parameters))
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
        let response = try await connectionService.send(Paths.getItems(parameters: parameters))
        try Task.checkCancellation()

        let nextStartItemIndex =
          if let startIndex = response.value.startIndex, let numItems = response.value.items?.count {
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
    return try? connectionService.createItemImageURL(item, size: size)
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
