//
//  AudiobookShelfRootView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct AudiobookShelfRootView: View {
  @StateObject var navigation: BPNavigation
  @StateObject var connectionViewModel: AudiobookShelfConnectionViewModel

  @EnvironmentObject private var singleFileDownloadService: SingleFileDownloadService
  @EnvironmentObject private var theme: ThemeViewModel

  @Environment(\.dismiss) var dismiss

  init(connectionService: AudiobookShelfConnectionService) {
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
      AudiobookShelfConnectionView(viewModel: connectionViewModel)
        .toolbar {
          ToolbarItemGroup(placement: .cancellationAction) {
            cancelToolbarButton
          }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: AudiobookShelfLibraryLevelData.self) { destination in
          switch destination {
          case .library(let source, let title):
            AudiobookShelfLibraryView(
              viewModel: AudiobookShelfLibraryViewModel(
                source: source,
                connectionService: connectionViewModel.connectionService,
                singleFileDownloadService: singleFileDownloadService,
                navigation: navigation,
                navigationTitle: title
              )
            )
          case .details(let item):
            AudiobookShelfAudiobookDetailsView(
              viewModel: AudiobookShelfAudiobookDetailsViewModel(
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
