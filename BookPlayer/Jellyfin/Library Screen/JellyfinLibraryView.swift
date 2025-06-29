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

  var navigationTitle: Text {
    if viewModel.editMode.isEditing, !viewModel.selectedItems.isEmpty {
      return Text("\(viewModel.selectedItems.count) of \(viewModel.totalItems) Items")
    } else {
      return Text(viewModel.navigationTitle)
    }
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
    .environment(\.editMode, $viewModel.editMode)
    .toolbar {
      ToolbarItem(placement: .principal) {
        navigationTitle
          .font(.headline)
          .foregroundColor(themeViewModel.primaryColor)
      }
      ToolbarItemGroup(placement: .topBarTrailing) {
        toolbarTrailing
      }
    }
    .toolbar {
      if viewModel.editMode.isEditing {
        ToolbarItemGroup(placement: .bottomBar) {
          bottomBar
        }
      }
    }
    .overlay {
      if viewModel.downloadRemaining > 0 {
        LoadingHUD(
          remaining: viewModel.downloadRemaining,
          total: viewModel.selectedItems.count
        )
        .transition(.opacity)
      }
    }
    .animation(.easeInOut(duration: 0.3), value: viewModel.downloadRemaining != 0)
  }

  @ViewBuilder
  var toolbarTrailing: some View {
    if !viewModel.editMode.isEditing {
      Menu {
        if #available(iOS 17.0, *) {
          Section {
            Button(action: viewModel.onEditToggleSelectTapped) {
              Label("Select".localized, systemImage: "checkmark.circle")
            }
          }
        }

        layoutPreferences
      } label: {
        Label("more_title".localized, systemImage: "ellipsis.circle")
      }
    } else {
      Button(action: viewModel.onEditToggleSelectTapped) {
        Text("Done".localized).bold()
      }
    }
  }

  @ViewBuilder
  var layoutPreferences: some View {
    Section {
      Picker(selection: $viewModel.layout, label: Text("Layout options".localized)) {
        Label("Grid".localized, systemImage: "square.grid.2x2").tag(JellyfinLayout.Options.grid)
        Label("List".localized, systemImage: "list.bullet").tag(JellyfinLayout.Options.list)
      }
    }
    Section {
      Picker(selection: $viewModel.sortBy, label: Text("Sort by".localized)) {
        Text("Default".localized).tag(JellyfinLayout.SortBy.smart)
        Label("Name".localized, systemImage: "textformat.abc").tag(JellyfinLayout.SortBy.name)
      }
    }
  }

  @ViewBuilder
  var bottomBar: some View {
    Button(action: viewModel.onSelectAllTapped) {
      Image(systemName: viewModel.selectedItems.isEmpty ? "checklist.checked" : "checklist.unchecked")
    }

    Spacer()

    Button(action: viewModel.onDownloadTapped) {
      Image(systemName: "arrow.down.to.line")
    }
    .disabled(viewModel.selectedItems.isEmpty)
  }
}

extension JellyfinLibraryView {
  struct LoadingHUD: View {
    let remaining: Int
    let total: Int

    private var downloaded: Int { total - remaining }

    private var progress: Double {
      guard total > 0 else { return 0 }
      return Double(downloaded) / Double(total)
    }

    var body: some View {
      ZStack {
        Color.black.opacity(0.4)
          .ignoresSafeArea()
          .onTapGesture {}

        VStack(spacing: 24) {
          ZStack {
            Circle()
              .stroke(Color.white.opacity(0.3), lineWidth: 6)
              .frame(width: 80, height: 80)

            Circle()
              .trim(from: 0, to: progress)
              .stroke(Color.white, lineWidth: 6)
              .frame(width: 80, height: 80)
              .rotationEffect(Angle(degrees: -90))
              .animation(.easeInOut(duration: 0.5), value: progress)

            Text("\(downloaded)")
              .foregroundColor(.white)
              .font(.title2)
              .fontWeight(.semibold)
          }

          VStack(spacing: 8) {
            HStack {
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))

              Text("Downloading...".localized)
                .foregroundColor(.white)
                .font(.headline)
            }

            Text("\(downloaded) of \(total) items".localized)
              .foregroundColor(.white.opacity(0.8))
              .font(.subheadline)
          }
        }
        .padding(32)
        .background(Color.black.opacity(0.85))
        .cornerRadius(16)
        .shadow(radius: 10)
      }
    }
  }
}
