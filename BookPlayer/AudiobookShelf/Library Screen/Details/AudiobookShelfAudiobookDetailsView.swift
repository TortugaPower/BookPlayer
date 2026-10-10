//
//  AudiobookShelfAudiobookDetailsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

/// Thin wrapper providing AudiobookShelf-specific image view to the shared details view.
struct AudiobookShelfAudiobookDetailsView<
  Model: IntegrationDetailsViewModelProtocol
>: View
where Model.Item == AudiobookShelfLibraryItem, Model.Details == AudiobookShelfAudiobookDetailsData {

  /// OWNS the VM (repo pattern, see ItemListView.init(initModel:)): this wrapper is
  /// re-created whenever the root's navigationDestination builder re-evaluates (e.g.
  /// tapping Stream mutates importManager, an @EnvironmentObject of the root), and an
  /// @ObservedObject over an inline-constructed VM was recreated each time — losing
  /// error/isImporting state and refetching. @StateObject storage survives; the
  /// initModel closure runs only on first install.
  @StateObject var viewModel: Model
  var onDownloadTap: () -> Void

  init(
    initModel: @escaping () -> Model,
    onDownloadTap: @escaping () -> Void
  ) {
    self._viewModel = .init(wrappedValue: initModel())
    self.onDownloadTap = onDownloadTap
  }
  
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
