//
//  JellyfinLibraryView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct JellyfinLibraryView<Model: JellyfinLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @StateObject private var themeViewModel = ThemeViewModel()
  @ScaledMetric private var accessabilityScale: CGFloat = 1
  
  @State private var availableSize: CGSize = .zero
  private let itemMinSizeBase = CGSize(width: 150, height: 150)
  private let itemMaxSizeBase = CGSize(width: 250, height: 250)
  private let itemSpacingBase = 20.0
  
  var body: some View {
    GeometryReader { geometry in
      AdaptiveVGrid(
        numItems: viewModel.userViews.count,
        itemMinSize: adjustSize(itemMinSizeBase, availableSize: geometry.size),
        itemMaxSize: adjustSize(itemMaxSizeBase, availableSize: geometry.size),
        itemSpacing: itemSpacingBase * accessabilityScale
      ) {
        ForEach(viewModel.userViews, id: \.id) { userView in
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
    .navigationTitle(viewModel.libraryName)
    .environmentObject(viewModel)
    .onAppear { viewModel.fetchUserViews() }
    .onDisappear { viewModel.cancelFetchUserViews() }
    .navigationTitle(viewModel.libraryName)
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
    let childViewModel = viewModel.createFolderViewModelFor(item: item)
    NavigationLink {
      NavigationLazyView(JellyfinLibraryFolderView(viewModel: childViewModel))
    } label: {
      JellyfinLibraryItemView<Model.FolderViewModel>(item: item)
        .environmentObject(childViewModel)
    }
    .buttonStyle(PlainButtonStyle())
  }
  
  private func adjustSize(_ size: CGSize, availableSize: CGSize) -> CGSize {
    CGSize(width: min(size.width, availableSize.width),
           height: min(size.height * accessabilityScale, availableSize.height))
  }
}

class MockJellyfinLibraryViewModel: JellyfinLibraryViewModelProtocol, ObservableObject {
  let libraryName: String = "Mock"
  @Published var userViews: [JellyfinLibraryItem] = []
  
  func fetchUserViews() {}
  func cancelFetchUserViews() {}
  
  func createFolderViewModelFor(item: JellyfinLibraryItem) -> MockJellyfinLibraryFolderViewModel {
    let data = JellyfinLibraryLevelData.folder(data: item)
    return MockJellyfinLibraryFolderViewModel(data: data)
  }
  
  func handleDoneAction() {}
}

#Preview {
  let viewModel = {
    let viewModel = MockJellyfinLibraryViewModel()
    viewModel.userViews = [
      JellyfinLibraryItem(id: "0", name: "View 0", kind: .userView),
      JellyfinLibraryItem(id: "1", name: "View 1", kind: .userView),
      //JellyfinLibraryItem(id: "2", name: "View 2", kind: .userView),
      //JellyfinLibraryItem(id: "3", name: "View 3", kind: .userView),
      //JellyfinLibraryItem(id: "4", name: "View 4", kind: .userView),
      //JellyfinLibraryItem(id: "5", name: "View 5", kind: .userView),
      //JellyfinLibraryItem(id: "6", name: "View 6", kind: .userView),
      //JellyfinLibraryItem(id: "7", name: "View 7", kind: .userView),
      //JellyfinLibraryItem(id: "8", name: "View 8", kind: .userView),
      //JellyfinLibraryItem(id: "9", name: "View 9", kind: .userView),
    ]
    return viewModel
  }()
  JellyfinLibraryView(viewModel: viewModel)
}
