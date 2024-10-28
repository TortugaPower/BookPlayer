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
}

protocol JellyfinLibraryViewModelProtocol: ObservableObject {
  associatedtype FolderViewModel: JellyfinLibraryFolderViewModelProtocol

  var libraryName: String { get }
  var userViews: [JellyfinLibraryItem] { get set }

  func fetchUserViews()

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> FolderViewModel
}

class JellyfinLibraryViewModel: ViewModelProtocol, JellyfinLibraryViewModelProtocol {
  weak var coordinator: JellyfinCoordinator!

  private var apiClient: JellyfinClient!

  let libraryName: String
  @Published var userViews: [JellyfinLibraryItem] = []

  init(libraryName: String, apiClient: JellyfinClient) {
    self.libraryName = libraryName
    self.apiClient = apiClient
  }

  func fetchUserViews() {
    self.userViews = []

    let parameters = Paths.GetUserViewsParameters(presetViews: [.books])
    Task {
      let response = try await apiClient.send(Paths.getUserViews(parameters: parameters))
      let userViews = (response.value.items ?? [])
        .compactMap { userView -> JellyfinLibraryItem? in
          guard userView.collectionType == .books, let id = userView.id else {
            return nil
          }
          let name = userView.name ?? userView.id!
          return JellyfinLibraryItem(id: id, name: name, kind: .userView)
        }
      await { @MainActor in
        self.userViews = userViews
      }()
    }
  }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> JellyfinLibraryFolderViewModel {
    return JellyfinLibraryFolderViewModel(data: item, apiClient: apiClient)
  }
}
