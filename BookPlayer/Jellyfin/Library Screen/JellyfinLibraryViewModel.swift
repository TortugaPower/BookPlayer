//
//  JellyfinLibraryViewModel.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation

class JellyfinLibraryViewModel: ViewModelProtocol, ObservableObject {
  weak var coordinator: JellyfinCoordinator!

  struct UserView: Identifiable, Hashable {
    let id: String
    let name: String
  }

  struct Item: Identifiable, Hashable {
    let id: String
    let name: String
  }

  @Published var userViews: [UserView] = []
  @Published var selectedView: UserView?
  @Published var items: [Item] = []

  func selectUserView(_ view: UserView) {
    selectedView = view
  }
}
