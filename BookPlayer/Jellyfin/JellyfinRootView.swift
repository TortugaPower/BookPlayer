//
//  JellyfinRootView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

@MainActor
final class BPNavigation: ObservableObject {
  var dismiss: DismissAction?

  @Published var path = NavigationPath()

  nonisolated init() {}
}

struct JellyfinRootView: View {
  @StateObject var navigation: BPNavigation
  @StateObject var connectionViewModel: JellyfinConnectionViewModel

  @EnvironmentObject private var singleFileDownloadService: SingleFileDownloadService
  @EnvironmentObject private var theme: ThemeViewModel

  @Environment(\.dismiss) var dismiss

  init(connectionService: JellyfinConnectionService) {
    let navigation = BPNavigation()
    self._navigation = .init(wrappedValue: navigation)
    self._connectionViewModel = .init(
      wrappedValue: .init(
        connectionService: connectionService,
        navigation: navigation
      )
    )
  }

  var body: some View {
    NavigationStack(path: $navigation.path) {
      JellyfinConnectionView(viewModel: connectionViewModel)
        .toolbar {
          ToolbarItemGroup(placement: .cancellationAction) {
            cancelToolbarButton
          }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: JellyfinLibraryLevelData.self) { destination in
          switch destination {
          case .topLevel(let libraryName):
            JellyfinLibraryView(
              viewModel: JellyfinLibraryViewModel(
                folderID: nil,
                connectionService: connectionViewModel.connectionService,
                singleFileDownloadService: singleFileDownloadService,
                navigation: navigation,
                navigationTitle: libraryName
              )
            )
          case .folder(let item):
            JellyfinLibraryView(
              viewModel: JellyfinLibraryViewModel(
                folderID: item.id,
                connectionService: connectionViewModel.connectionService,
                singleFileDownloadService: singleFileDownloadService,
                navigation: navigation,
                navigationTitle: item.name
              )
            )
          case .details(let item):
            JellyfinAudiobookDetailsView(
              viewModel: JellyfinAudiobookDetailsViewModel(
                item: item,
                connectionService: connectionViewModel.connectionService,
                singleFileDownloadService: singleFileDownloadService
              )
            ) {
              dismiss()
            }
          }
        }
    }
    .tint(theme.linkColor)
    .environmentObject(theme)
    .onAppear {
      navigation.dismiss = dismiss
    }
  }

  @ViewBuilder
  private var cancelToolbarButton: some View {
    Button(
      action: {
        dismiss()
      },
      label: {
        Image(systemName: "xmark")
          .foregroundStyle(theme.linkColor)
      }
    )
  }
}
