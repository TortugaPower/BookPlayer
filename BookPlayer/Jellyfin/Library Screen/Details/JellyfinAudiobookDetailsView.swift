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
}
