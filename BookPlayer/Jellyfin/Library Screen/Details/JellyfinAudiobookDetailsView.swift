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
        JellyfinLibraryItemImageView(item: viewModel.item)
          .environment(\.jellyfinService, jellyfinConnectionService)
      }
    )
  }

  private var jellyfinConnectionService: JellyfinConnectionService {
    (viewModel as? JellyfinAudiobookDetailsViewModel)?.connectionService ?? .init()
  }
}
