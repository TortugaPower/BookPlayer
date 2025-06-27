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
  @StateObject private var themeViewModel = ThemeViewModel()

  var navigationTitle: String {
    viewModel.navigationTitle
  }

  var body: some View {
    Group {
      if viewModel.layout == .grid {
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
          Section {
            Picker(selection: $viewModel.layout, label: Text("Layout options")) {
              Label("Grid", systemImage: "square.grid.2x2").tag(JellyfinLayout.Options.grid)
              Label("List", systemImage: "list.bullet").tag(JellyfinLayout.Options.list)
            }
          }
          Section {
            Picker(selection: $viewModel.sortBy, label: Text("Sort by")) {
              Text("Default").tag(JellyfinLayout.SortBy.smart)
              Label("Name", systemImage: "textformat.abc").tag(JellyfinLayout.SortBy.name)
            }
          }
        } label: {
          Label("more_title".localized, systemImage: "ellipsis.circle")
        }
      }
    }
  }
}
