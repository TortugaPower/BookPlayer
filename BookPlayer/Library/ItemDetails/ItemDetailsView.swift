//
//  ItemDetailsView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import PhotosUI
import SwiftUI

struct ItemDetailsView: View {
  /// View model for the form
  @StateObject private var viewModel: ItemDetailsViewModel
  /// Flag to show action sheet for the artwork
  @State private var showingArtworkOptions = false
  /// Flag to show the ImagePicker
  @State private var showingImagePicker = false
  /// Flag to show the empty pasteboard alert
  @State private var showingEmptyPasteboardAlert = false

  @State private var loadingState = LoadingOverlayState()

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var theme: ThemeViewModel

  init(initModel: @escaping () -> ItemDetailsViewModel) {
    self._viewModel = .init(wrappedValue: initModel())
  }

  var body: some View {
    Form {
      ItemDetailsTitleSectionView(
        title: $viewModel.title,
        titlePlaceholder: viewModel.titlePlaceholder,
        showAuthor: viewModel.showAuthor,
        author: $viewModel.author,
        authorPlaceholder: viewModel.authorPlaceholder
      )

      ItemDetailsArtworkSectionView(image: $viewModel.selectedImage) {
        showingArtworkOptions = true
      }

      ItemDetailsFooterSectionView(
        originalFileName: viewModel.originalFileName,
        progress: viewModel.progress,
        lastPlayedDate: viewModel.lastPlayedDate
      )
    }
    .onChange(of: viewModel.selectedImage) {
      viewModel.artworkIsUpdated = true
    }
    .sheet(isPresented: $showingImagePicker) {
      ImagePicker(image: $viewModel.selectedImage)
    }
    .alert("artwork_clipboard_empty_title", isPresented: $showingEmptyPasteboardAlert) {
      Button("ok_button") {}
    }
    .confirmationDialog("artwork_options_title", isPresented: $showingArtworkOptions) {
      Button("artwork_photolibrary_title") {
        showingImagePicker = true
      }
      Button("artwork_clipboard_title") {
        if let image = UIPasteboard.general.image {
          viewModel.selectedImage = image
        } else {
          showingEmptyPasteboardAlert = true
        }
      }
      Button("cancel_button", role: .cancel) {}
    }
    .errorAlert(error: $loadingState.error)
    .loadingOverlay(loadingState.show)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button("cancel_button", role: .cancel) {
          dismiss()
        }
      }

      ToolbarItem(placement: .primaryAction) {
        Button("save_button") {
          viewModel.handleSaveAction(loadingState) {
            dismiss()
          }
        }
      }
    }
    .navigationTitle("edit_title")
    .navigationBarTitleDisplayMode(.inline)
    .listSectionSpacing(Spacing.S2)
    .applyListStyle(with: theme, background: theme.systemGroupedBackgroundColor)
  }
}
