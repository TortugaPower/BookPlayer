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
  /// Media Servers, presented on top of the editor so its edits stay
  @State private var showingMediaServers = false

  @Environment(\.hardcoverService) private var hardcoverService
  @Environment(\.jellyfinService) private var jellyfinService
  @Environment(\.audiobookshelfService) private var audiobookshelfService
  @Environment(\.listState) private var listState
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

      // The gate lives HERE: the section renders what it's given, the caller decides presence
      let mediaServerResources = viewModel.hostedExternalResources
      if viewModel.hardcoverSectionViewModel != nil || !mediaServerResources.isEmpty {
        ItemDetailsIntegrationsSectionView(
          hardcover: viewModel.hardcoverSectionViewModel,
          mediaServerResources: mediaServerResources,
          resolvedHosts: viewModel.resolvedExternalHosts,
          onOpenMediaServers: { showingMediaServers = true }
        )
      }

      ItemDetailsFooterSectionView(
        originalFileName: viewModel.originalFileName,
        progress: viewModel.progress,
        lastPlayedDate: viewModel.lastPlayedDate
      )
    }
    .task {
      await viewModel.load()
    }
    .onChange(of: viewModel.selectedImage) {
      viewModel.artworkIsUpdated = true
    }
    .sheet(isPresented: $showingImagePicker) {
      ImagePicker(image: $viewModel.selectedImage)
    }
    // Registered as a cover like the library's own Media Servers sheet: an import confirmed in
    // the browser waits for it to close before its placement prompt
    .sheet(isPresented: $showingMediaServers, onDismiss: {
      listState.coversOnScreen.remove(.mediaServers)
    }) {
      NavigationStack {
        MediaServersView(
          jellyfinService: jellyfinService,
          audiobookshelfService: audiobookshelfService,
          style: .libraryEntry
        )
      }
      .environment(\.closeMediaServers, CloseMediaServersAction { showingMediaServers = false })
      .onAppear { listState.coversOnScreen.insert(.mediaServers) }
    }
    .alert(
      "hardcover_remove_confirmation_title",
      isPresented: $viewModel.showHardcoverRemovalAlert,
      presenting: viewModel.hardcoverAlertPayload
    ) { payload in
      Button("hardcover_remove_keep_it", role: .cancel) {
        Task {
          await viewModel.assignNewSelection(payload.newSelection)
          viewModel.handleSaveAction(loadingState) {
            dismiss()
          }
        }
      }
      Button("hardcover_remove_remove_it", role: .destructive) {
        Task {
          do {
            try await hardcoverService.removeFromLibrary(payload.book)
            await viewModel.assignNewSelection(payload.newSelection)
            viewModel.handleSaveAction(loadingState) {
              dismiss()
            }
          } catch {
            loadingState.error = error
          }
        }
      }
    } message: { payload in
      Text(String(format: "hardcover_remove_confirmation_message".localized, payload.book.title, payload.book.author))
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
