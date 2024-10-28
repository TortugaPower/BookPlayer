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

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> JellyfinLibraryFolderViewModel {
    return JellyfinLibraryFolderViewModel(data: item, apiClient: apiClient)
  }
}
