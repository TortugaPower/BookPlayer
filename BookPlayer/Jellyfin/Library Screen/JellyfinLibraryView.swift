//
//  JellyfinLibraryView.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct JellyfinLibraryView<Model: JellyfinLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @StateObject var themeViewModel = ThemeViewModel()

  struct UserView: View {
    let name: String
    var body: some View {
      ZStack {
        Text(name)
          .font(.title)
          .multilineTextAlignment(.center)
      }
      .frame(width: 100, height: 100)
    }
  }

  var body: some View {
    let columns = [
      GridItem(.adaptive(minimum: 100))
    ]
    LazyVGrid(columns: columns) {
      ForEach(viewModel.userViews, id: \.id) { userView in
        let folderRepresentation = JellyfinLibraryItem(id: userView.id, name: userView.name, kind: .folder)
        let childViewModel = viewModel.createFolderViewModelFor(item: folderRepresentation)
        NavigationLink(destination: NavigationLazyView(JellyfinLibraryFolderView(viewModel: childViewModel))) {
          UserView(name: userView.name)
        }
      }
    }
  }
}

class MockJellyfinLibraryViewModel: JellyfinLibraryViewModelProtocol, ObservableObject {
  @Published var userViews: [UserView] = []

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> MockJellyfinLibraryFolderViewModel {
    return MockJellyfinLibraryFolderViewModel(data: item)
  }
}

#Preview {
  let viewModel = {
    let viewModel = MockJellyfinLibraryViewModel()
    viewModel.userViews = [
      JellyfinLibraryViewModel.UserView(id: "0", name: "First View"),
      JellyfinLibraryViewModel.UserView(id: "1", name: "Second View"),
      JellyfinLibraryViewModel.UserView(id: "2", name: "Third View"),
      JellyfinLibraryViewModel.UserView(id: "3", name: "Fourth View"),
    ]
    return viewModel
  }()
  JellyfinLibraryView(viewModel: viewModel)
}
