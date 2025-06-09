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
  @StateObject var viewModel: Model
  @AppStorage(Constants.UserDefaults.jellyfinLibraryLayout) var libraryLayout: JellyfinLayoutOptions = .grid
  @StateObject private var themeViewModel = ThemeViewModel()

  var navigationTitle: String {
    viewModel.navigationTitle
  }

  var body: some View {
    Group {
      if libraryLayout == .grid {
        JellyfinLibraryGridView(viewModel: viewModel)
          .padding()
      } else {
        JellyfinLibraryListView(viewModel: viewModel)
      }
    }
    .environmentObject(themeViewModel)
    .environmentObject(viewModel.connectionService)
    .onAppear { viewModel.fetchInitialItems() }
    .onDisappear { viewModel.cancelFetchItems() }
    .errorAlert(error: $viewModel.error)
    .toolbar {
      ToolbarItem(placement: .principal) {
        Text(navigationTitle)
          .font(.headline)
          .foregroundColor(themeViewModel.primaryColor)
      }
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
