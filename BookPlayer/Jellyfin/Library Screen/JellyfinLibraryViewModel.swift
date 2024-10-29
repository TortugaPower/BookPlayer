//
//  JellyfinLibraryViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import JellyfinAPI

struct JellyfinLibraryItem: Identifiable, Hashable {
  enum Kind {
    case userView
    case folder
    case audiobook
  }

  let id: String
  let name: String
  let kind: Kind

  let blurHash: String?
  let imageAspectRatio: Double?
}

extension JellyfinLibraryItem {
  init(id: String, name: String, kind: Kind) {
    self.init(id: id, name: name, kind: kind, blurHash: nil, imageAspectRatio: nil)
  }
}

extension JellyfinLibraryItem {
  init?(apiItem: BaseItemDto) {
    let kind: JellyfinLibraryItem.Kind? = switch apiItem.type {
    case .userView, .collectionFolder: .userView
    case .folder: .folder
    case .audioBook: .audiobook
    default: nil
    }

    guard let id = apiItem.id, let kind else {
      return nil
    }
    let name = apiItem.name ?? id
    let blurHash = apiItem.imageBlurHashes?.primary?.first?.value

    self.init(id: id, name: name, kind: kind, blurHash: blurHash, imageAspectRatio: apiItem.primaryImageAspectRatio)
  }
}

protocol JellyfinLibraryViewModelProtocol: ObservableObject {
  associatedtype FolderViewModel: JellyfinLibraryFolderViewModelProtocol

  var libraryName: String { get }
  var userViews: [JellyfinLibraryItem] { get set }

  func fetchUserViews()
  func cancelFetchUserViews()

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> FolderViewModel
}

class JellyfinLibraryViewModel: ViewModelProtocol, JellyfinLibraryViewModelProtocol {
  weak var coordinator: JellyfinCoordinator!

  private let apiClient: JellyfinClient
  private let userID: String

  let libraryName: String
  @Published var userViews: [JellyfinLibraryItem] = []

  private var fetchTask: Task<(), any Error>?

  init(libraryName: String, userID: String, apiClient: JellyfinClient) {
    self.apiClient = apiClient
    self.userID = userID
    self.libraryName = libraryName
  }

  func fetchUserViews() {
    userViews = []

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
        self.userViews = userViews
      }()
    }
  }

  func cancelFetchUserViews() {
    fetchTask?.cancel()
    fetchTask = nil
  }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> JellyfinLibraryFolderViewModel {
    return JellyfinLibraryFolderViewModel(data: item, apiClient: apiClient)
  }
}
