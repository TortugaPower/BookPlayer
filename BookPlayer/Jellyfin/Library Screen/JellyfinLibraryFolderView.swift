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
      itemLinkView(item)
        .onAppear {
          self.viewModel.fetchMoreItemsIfNeeded(currentItem: item)
        }
    }
    .navigationTitle(viewModel.data.name)
    .onAppear {
      self.viewModel.fetchInitialItems()
    }
  }

  @ViewBuilder
  private func itemLinkView(_ item: JellyfinLibraryItem) -> some View {
    switch item.kind {
    case .audiobook:
      itemView(item)
    case .folder:
      let childViewModel = viewModel.createFolderViewModelFor(item: item) as! Model
      NavigationLink(destination: NavigationLazyView(JellyfinLibraryFolderView(viewModel: childViewModel))) {
        itemView(item)
      }
    }
  }

  @ViewBuilder
  private func itemView(_ item: JellyfinLibraryItem) -> some View {
    VStack(alignment: .leading) {
      KFImage
        .url(viewModel.createItemImageURL(item))
        .cacheMemoryOnly()
        .resizable()
        .placeholder { ProgressView() }
        .frame(width: 100, height: 100)
        .cornerRadius(3)

      Text(item.name)
    }
  }
}

class MockJellyfinLibraryFolderViewModel: JellyfinLibraryFolderViewModelProtocol, ObservableObject {
  let data: Item
  @Published var items: [Item] = []

  init(data: Item) {
    self.data = data
  }

  func createFolderViewModelFor(item: JellyfinLibraryItem) -> MockJellyfinLibraryFolderViewModel {
    return MockJellyfinLibraryFolderViewModel(data: item)
  }

  func fetchInitialItems() {}
  func fetchMoreItemsIfNeeded(currentItem: Item) {}

  func createItemImageURL(_ item: Item) -> URL? { nil }
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
