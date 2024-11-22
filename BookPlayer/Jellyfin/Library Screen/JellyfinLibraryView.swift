//
//  JellyfinLibraryView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-27.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI
import Kingfisher

struct JellyfinLibraryView<Model: JellyfinLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @StateObject private var themeViewModel = ThemeViewModel()
  @ScaledMetric var accessabilityScale: CGFloat = 1
  
  @State private var availableSize: CGSize = .zero
  private let itemMinSizeBase = CGSize(width: 100, height: 100)
  private let itemMaxSizeBase = CGSize(width: 250, height: 250)
  private let itemSpacingBase = 20.0
  
  var navigationTitle: String {
    switch viewModel.data {
    case .topLevel(libraryName: let libraryName, userID: _):
      libraryName
    case .folder(data: let data):
      data.name
    }
  }

  var body: some View {
    GeometryReader { geometry in
      AdaptiveVGrid(
        numItems: viewModel.items.count,
        itemMinSize: adjustSize(itemMinSizeBase, availableSize: geometry.size),
        itemMaxSize: adjustSize(itemMaxSizeBase, availableSize: geometry.size),
        itemSpacing: itemSpacingBase * accessabilityScale
      ) {
        ForEach(viewModel.items, id: \.id) { userView in
          itemView(item: userView)
            .frame(minWidth: adjustSize(itemMinSizeBase, availableSize: geometry.size).width,
                   maxWidth: CGFloat.greatestFiniteMagnitude,
                   minHeight: adjustSize(itemMinSizeBase, availableSize: geometry.size).height,
                   maxHeight: adjustSize(itemMaxSizeBase, availableSize: geometry.size).height
            )
        }
      }
    }
    .padding()
    .environmentObject(viewModel)
    .onAppear { viewModel.fetchInitialItems() }
    .onDisappear { viewModel.cancelFetchItems() }
    .navigationTitle(navigationTitle)
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button(
          action: viewModel.handleDoneAction,
          label: {
            Image(systemName: "xmark")
              .foregroundColor(themeViewModel.linkColor)
          }
        )
      }
    }
  }
  
  @ViewBuilder
  private func itemView(item: JellyfinLibraryItem) -> some View {
    JellyfinLibraryItemView<Model>(item: item)
      .onAppear {
        viewModel.fetchMoreItemsIfNeeded(currentItem: item)
      }
  }
  
  private func adjustSize(_ size: CGSize, availableSize: CGSize) -> CGSize {
    CGSize(width: min(size.width, availableSize.width),
           height: min(size.height * accessabilityScale, availableSize.height))
  }
}

class MockJellyfinLibraryViewModel: JellyfinLibraryViewModelProtocol, ObservableObject {
  let data: JellyfinLibraryLevelData
  @Published var items: [JellyfinLibraryItem] = []
  
  init(data: JellyfinLibraryLevelData) {
    self.data = data
  }
  
  func createFolderViewModelFor(item: JellyfinLibraryItem) -> MockJellyfinLibraryViewModel {
    let data = JellyfinLibraryLevelData.folder(data: item)
    return MockJellyfinLibraryViewModel(data: data)
  }
  
  func fetchInitialItems() {}
  func fetchMoreItemsIfNeeded(currentItem: JellyfinLibraryItem) {}
  func cancelFetchItems() {}
  
  func createItemImageURL(_ item: JellyfinLibraryItem, size: CGSize?) -> URL? { nil }
  
  func beginDownloadAudiobook(_ item: JellyfinLibraryItem) {}
  
  func handleDoneAction() {}
}

#Preview("top level") {
  let model = {
    var model = MockJellyfinLibraryViewModel(data: .topLevel(libraryName: "Mock Library", userID: "42"))
    model.items = [
      JellyfinLibraryItem(id: "0.0", name: "subfolder", kind: .folder),
      JellyfinLibraryItem(id: "0.1", name: "book", kind: .audiobook),
      JellyfinLibraryItem(id: "0.2", name: "another book", kind: .audiobook),
      JellyfinLibraryItem(id: "0.3", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(id: "0.4", name: "book 2 with a very very long name\nmaybe even a line break?", kind: .audiobook),
      JellyfinLibraryItem(id: "0.5", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.6", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.7", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.8", name: "another book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.9", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(id: "0.10", name: "book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.11", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.12", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.13", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.14", name: "another book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.15", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(id: "0.16", name: "book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.17", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.18", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.19", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.20", name: "another book 3", kind: .audiobook),
    ]
    return model
  }()
  JellyfinLibraryView(viewModel: model)
}

#Preview("folder") {
  let model = {
    let topLevelFolder = JellyfinLibraryItem(id: "0", name: "some folder", kind: .folder)
    var model = MockJellyfinLibraryViewModel(data: .folder(data: topLevelFolder))
    model.items = [
      JellyfinLibraryItem(id: "0.0", name: "subfolder", kind: .folder),
      JellyfinLibraryItem(id: "0.1", name: "book", kind: .audiobook),
      JellyfinLibraryItem(id: "0.2", name: "another book", kind: .audiobook),
      JellyfinLibraryItem(id: "0.3", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(id: "0.4", name: "book 2 with a very very long name\nmaybe even a line break?", kind: .audiobook),
      JellyfinLibraryItem(id: "0.5", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.6", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.7", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.8", name: "another book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.9", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(id: "0.10", name: "book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.11", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.12", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.13", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.14", name: "another book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.15", name: "subfolder 2", kind: .folder),
      JellyfinLibraryItem(id: "0.16", name: "book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.17", name: "another book 2", kind: .audiobook),
      JellyfinLibraryItem(id: "0.18", name: "subfolder 3", kind: .folder),
      JellyfinLibraryItem(id: "0.19", name: "book 3", kind: .audiobook),
      JellyfinLibraryItem(id: "0.20", name: "another book 3", kind: .audiobook),
    ]
    return model
  }()
  JellyfinLibraryView(viewModel: model)
}
