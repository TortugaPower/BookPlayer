//
//  IntegrationLibraryGridView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct IntegrationLibraryGridView<
  Model: IntegrationLibraryViewModelProtocol,
  CellContent: View
>: View {
  @ObservedObject var viewModel: Model
  @ViewBuilder let cellContent: (Model.Item) -> CellContent

  @ScaledMetric var accessabilityScale: CGFloat = 1
  private let itemMinSizeBase = CGSize(width: 100, height: 100)
  private let itemMaxSizeBase = CGSize(width: 250, height: 250)
  private let itemSpacingBase = 20.0

  private var columns: [GridItem] {
    [GridItem(
      .adaptive(
        minimum: itemMinSizeBase.width,
        maximum: itemMaxSizeBase.width
      ),
      spacing: itemSpacingBase * accessabilityScale
    )]
  }

  var body: some View {
    LazyVGrid(columns: columns, spacing: itemSpacingBase * accessabilityScale) {
      ForEach(viewModel.items, id: \.id) { item in
        cellContent(item)
          .accessibilityAddTraits(.isButton)
          .onTapGesture {
            if viewModel.editMode.isEditing {
              guard item.isDownloadable else { return }
              viewModel.onSelectTapped(for: item)
            } else if let destination = viewModel.destination(for: item) {
              viewModel.navigation.path.append(destination)
            }
          }
          .onAppear {
            viewModel.fetchMoreItemsIfNeeded(currentItem: item)
          }
      }
    }
  }
}
