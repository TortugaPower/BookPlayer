//
//  AudiobookShelfAudiobookDetailsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

/// Thin wrapper providing AudiobookShelf-specific image view to the shared details view.
struct AudiobookShelfAudiobookDetailsView<
  Model: IntegrationDetailsViewModelProtocol
>: View
where Model.Item == AudiobookShelfLibraryItem, Model.Details == AudiobookShelfAudiobookDetailsData {

  @ObservedObject var viewModel: Model
  var onDownloadTap: () -> Void

  var body: some View {
    IntegrationAudiobookDetailsView(
      viewModel: viewModel,
      onDownloadTap: onDownloadTap,
      imageContent: {
        AudiobookShelfLibraryItemImageView(item: viewModel.item)
          .environment(\.audiobookshelfService, audiobookShelfConnectionService)
      }
    )
  }

  private var audiobookShelfConnectionService: AudiobookShelfConnectionService {
    (viewModel as? AudiobookShelfAudiobookDetailsViewModel)?.connectionService ?? .init()
  }
}
