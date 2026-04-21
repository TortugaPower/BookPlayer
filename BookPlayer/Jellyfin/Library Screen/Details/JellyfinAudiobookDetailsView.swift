//
//  JellyfinAudiobookDetailsView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// Thin wrapper providing Jellyfin-specific image view to the shared details view.
struct JellyfinAudiobookDetailsView<
  Model: IntegrationDetailsViewModelProtocol
>: View
where Model.Item == JellyfinLibraryItem, Model.Details == JellyfinAudiobookDetailsData {

  @ObservedObject var viewModel: Model
  var onDownloadTap: () -> Void

  var body: some View {
    IntegrationAudiobookDetailsView(
      viewModel: viewModel,
      onDownloadTap: onDownloadTap,
      imageContent: {
        JellyfinLibraryItemImageView(item: viewModel.item)
          .environment(\.jellyfinService, jellyfinConnectionService)
      }
    )
  }

  private var jellyfinConnectionService: JellyfinConnectionService {
    (viewModel as? JellyfinAudiobookDetailsViewModel)?.connectionService ?? .init()
  }
  
  var DownloadButton: some View {
    Button {
      do {
        try viewModel.handleImportAudiobook(viewModel.item)
        onDownloadTap()
      } catch {
        viewModel.error = error
      }
    } label: {
      HStack {
        Image(systemName: "square.and.arrow.down")
        Text("Download")
          .fontWeight(.semibold)
      }
      .frame(height: 24)
      .frame(maxWidth: .infinity)
      .padding()
      .foregroundStyle(theme.primaryColor)
      .background(theme.tertiarySystemBackgroundColor)
      .cornerRadius(10)
    }
  }
  
  var SmallDownloadButton: some View {
    Button {
      do {
        try viewModel.handleImportAudiobook(viewModel.item)
        onDownloadTap()
      } catch {
        viewModel.error = error
      }
    } label: {
      HStack {
        Image(systemName: "square.and.arrow.down")
      }
      .frame(width: 36, height: 24)
      .padding()
      .foregroundStyle(theme.primaryColor)
      .background(theme.tertiarySystemBackgroundColor)
      .cornerRadius(10)
    }
  }
  
  var SynchronizeButton: some View {
    Button {
      if self.viewModel.accountService.hasLiteEnabled() {
        do {
          try self.viewModel.handleImportAudiobook(viewModel.item)
          onDownloadTap()
        } catch {
          viewModel.error = error
        }
      } else {
        self.viewModel.navigation.path.append(JellyfinLibraryLevelData.subscribe)
      }
    } label: {
      HStack {
        Image(systemName: "arrow.down.circle.dotted")
        Text("Stream")
          .foregroundStyle(theme.primaryColor)
          .bpFont(.title)
      }
      .frame(height: 24)
      .frame(maxWidth: .infinity)
      .padding()
      .foregroundStyle(theme.primaryColor)
      .background(theme.secondarySystemBackgroundColor)
      .cornerRadius(10)
    }
  }
}
