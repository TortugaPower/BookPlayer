//
//  JellyfinLibraryFolderView.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-27.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI
import Kingfisher

struct JellyfinLibraryFolderView<Model: JellyfinLibraryFolderViewModelProtocol>: View {
  @ObservedObject var viewModel: Model

  var body: some View {
    List(viewModel.items) { item in
      JellyfinLibraryItemView<Model>(item: item)
        .onAppear {
          viewModel.fetchMoreItemsIfNeeded(currentItem: item)
        }
    }
    .navigationTitle(viewModel.data.name)
    .environmentObject(viewModel)
    .onAppear { viewModel.fetchInitialItems() }
    .onDisappear { viewModel.cancelFetchItems() }
  }
}

class MockJellyfinLibraryFolderViewModel: JellyfinLibraryFolderViewModelProtocol, ObservableObject {
  let data: JellyfinLibraryItem
  @Published var items: [JellyfinLibraryItem] = []

  init(data: JellyfinLibraryItem) {
    self.data = data
  }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> MockJellyfinLibraryFolderViewModel {
    return MockJellyfinLibraryFolderViewModel(data: item)
  }

  func fetchInitialItems() {}
  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem) {}
  func cancelFetchItems() {}

  func createItemImageURL(_ item: JellyfinLibraryItem, size: CGSize?) -> URL? { nil }
}

#Preview {
  let model = {
    var model = MockJellyfinLibraryFolderViewModel(data: JellyfinLibraryItem(id: "0", name: "some folder", kind: .folder))
    model.items = [
      JellyfinLibraryItem(id: "0.0", name: "subfolder", kind: .folder),
      JellyfinLibraryItem(id: "0.1", name: "book", kind: .audiobook),
      JellyfinLibraryItem(id: "0.2", name: "another book", kind: .audiobook),
    ]
    return model
  }()
  JellyfinLibraryFolderView(viewModel: model)
}
