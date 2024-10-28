//
//  JellyfinLibraryViewModel.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-26.
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
  let imageAspectRatio: Double

  init(id: String, name: String, kind: Kind, blurHash: String? = nil, imageAspectRatio: Double = 1) {
    self.id = id
    self.name = name
    self.kind = kind
    self.blurHash = blurHash
    self.imageAspectRatio = imageAspectRatio
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
          guard userView.collectionType == .books, let id = userView.id else {
            return nil
          }
          let name = userView.name ?? id
          let blurHash = userView.imageBlurHashes?.primary?.first?.value
          let imageAspectRatio = userView.primaryImageAspectRatio ?? 1
          return JellyfinLibraryItem(id: id, name: name, kind: .userView, blurHash: blurHash, imageAspectRatio: imageAspectRatio)
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
