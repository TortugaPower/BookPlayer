//
//  JellyfinAudiobookDetailsView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

/// Thin wrapper providing Jellyfin-specific image view to the shared details view.
struct JellyfinAudiobookDetailsView<
  Model: IntegrationDetailsViewModelProtocol
>: View
where Model.Item == JellyfinLibraryItem, Model.Details == JellyfinAudiobookDetailsData {

  @ObservedObject var viewModel: Model
  var showSubscribeButton: Bool = false
  var allowStream: Bool = false
  var onDownloadTap: () -> Void
  var onStreamTap: () -> Void
  
  var body: some View {
    IntegrationAudiobookDetailsView(
      viewModel: viewModel,
      showSubscribeButton: showSubscribeButton,
      allowStream: allowStream,
      onDownloadTap: onDownloadTap,
      onStreamTap: onStreamTap,
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
