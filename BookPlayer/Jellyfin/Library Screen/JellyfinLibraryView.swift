//
//  JellyfinLibraryView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-27.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import SwiftUI

struct JellyfinLibraryView<Model: JellyfinLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayout) var libraryLayout: JellyfinLayoutOptions = .grid
  @StateObject private var themeViewModel = ThemeViewModel()

  var navigationTitle: String {
    switch viewModel.data {
    case .topLevel(let libraryName, userID: _):
      libraryName
    case .folder(let data):
      data.name
    }
  }

  var body: some View {
    Group {
      if libraryLayout == .grid {
        JellyfinLibraryGridView(viewModel: viewModel)
      } else {
        List {
          ForEach(viewModel.items, id: \.id) { userView in
            NavigationLink {
              NavigationLazyView(viewModel.createFolderViewFor(item: userView))
            } label: {
              VStack {
                Text(userView.name)
              }
            }
            .buttonStyle(PlainButtonStyle())
          }
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
        Menu {
          Picker(selection: $libraryLayout, label: Text("Layout options")) {
            Label("Grid", systemImage: "square.grid.2x2").tag(JellyfinLayoutOptions.grid)
            Label("List", systemImage: "list.bullet").tag(JellyfinLayoutOptions.list)
          }
        } label: {
          Label("more_title".localized, systemImage: "ellipsis.circle")
        }
      }
    }
  }
}
