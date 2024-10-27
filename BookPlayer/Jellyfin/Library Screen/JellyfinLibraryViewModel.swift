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
  enum Kind {
    case folder
    case audiobook
  }

  let id: String
  let name: String
  let kind: Kind
}

protocol JellyfinLibraryViewModelProtocol: ObservableObject {
  typealias UserView = JellyfinLibraryUserViewData
  associatedtype FolderViewModel: JellyfinLibraryFolderViewModelProtocol

  var userViews: [UserView] { get set }
  func createFolderViewModelFor(item: JellyfinLibraryItem) -> FolderViewModel
}

class JellyfinLibraryViewModel: ViewModelProtocol, JellyfinLibraryViewModelProtocol {
  typealias UserView = JellyfinLibraryUserViewData

  weak var coordinator: JellyfinCoordinator!

  private var apiClient: JellyfinClient!

  @Published var userViews: [UserView] = []

  init(apiClient: JellyfinClient) {
    self.apiClient = apiClient
  }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> JellyfinLibraryFolderViewModel {
    return JellyfinLibraryFolderViewModel(data: item, apiClient: apiClient)
  }
}
