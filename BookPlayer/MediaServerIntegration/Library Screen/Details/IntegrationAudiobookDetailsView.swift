//
//  IntegrationAudiobookDetailsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct IntegrationAudiobookDetailsView<
  Model: IntegrationDetailsViewModelProtocol,
  ImageContent: View
>: View {

  @State private var isFilePathExpanded: Bool = false
  @State private var isGenresExpanded: Bool = false
  @State private var isOverviewExpanded: Bool = true
  @State private var isTagsExpanded: Bool = true
  @ObservedObject var viewModel: Model
  @EnvironmentObject private var theme: ThemeViewModel

  var onDownloadTap: () -> Void
  @ViewBuilder let imageContent: () -> ImageContent

  var voiceOverBookInfo: String {
    guard let details = viewModel.details else {
      return viewModel.item.displayName
    }

    return VoiceOverService.playerMetaText(
      title: viewModel.item.displayName,
      author: details.artist ?? "voiceover_unknown_author".localized
    )
  }

  var body: some View {
    ScrollView {
      VStack {
        imageContent()
          .accessibilityHidden(true)
          .padding(.horizontal, Spacing.L1)

        Text(viewModel.item.displayName)
          .bpFont(.titleLarge)
          .accessibilityLabel(voiceOverBookInfo)
          .foregroundStyle(theme.primaryColor)
          .multilineTextAlignment(.center)

        if let artist = viewModel.details?.artist {
          Text(artist)
            .bpFont(.title2)
            .foregroundStyle(theme.secondaryColor)
            .lineLimit(1)
            .accessibilityHidden(true)
        }

        if let narrator = viewModel.details?.narrator, !narrator.isEmpty {
          Text(String(format: "audiobook_details_narrator_label".localized, narrator))
            .bpFont(.subheadline)
            .foregroundStyle(theme.secondaryColor)
            .lineLimit(1)
            .accessibilityHidden(true)
        }

        if let details = viewModel.details {
          HStack(alignment: .center) {
            Text(details.runtimeString)
              .accessibilityLabel("book_duration_title".localized + details.runtimeString)
            Text(" | ")
            Text(details.fileSizeString)
          }
          .foregroundStyle(theme.primaryColor)
          .bpFont(.caption)
        }

        // Both buttons always render: Stream sells the entitlement when it's missing,
        // Download always downloads. The old `if allowStream || showSubscribeButton`
        // was a tautology — showSubscribeButton was the exact negation of allowStream,
        // so the else branch was unreachable and both it and showSubscribeButton are
        // gone. The entitlement question lives inside the button instead: allowStream
        // is hasStreamingEnabled() (anyone who has ever paid), and SynchronizeButton
        // routes to goToSubscribe() when it is false.
        HStack(spacing: 12) {
          SmallDownloadButton
          SynchronizeButton
        }
        .padding(.horizontal)
        .padding(.vertical, 12)

        if let details = viewModel.details {
          VStack {
            if let filePath = details.filePath {
              DisclosureGroup("file_path_title".localized, isExpanded: $isFilePathExpanded) {
                Text(filePath)
              }
              .accessibilityHidden(true)
            }

            if let genres = details.genres, !genres.isEmpty {
              DisclosureGroup("genres_title".localized, isExpanded: $isGenresExpanded) {
                IntegrationTagsView(tags: genres)
              }
            }

            if let overview = details.overview {
              DisclosureGroup("overview_title".localized, isExpanded: $isOverviewExpanded) {
                Text(overview)
              }
            }

            if let tags = details.tags, !tags.isEmpty {
              DisclosureGroup("tags_title".localized, isExpanded: $isTagsExpanded) {
                IntegrationTagsView(tags: tags)
              }
            }

            if !details.seriesEntries.isEmpty {
              DisclosureGroup("series_title".localized, isExpanded: .constant(true)) {
                VStack(alignment: .leading, spacing: 8) {
                  ForEach(details.seriesEntries) { item in
                    Text(item.name)
                  }
                }
              }
            }
          }
          .padding(.horizontal)
        }
      }
    }
    .applyListStyle(with: theme, background: theme.systemBackgroundColor)
    .tint(theme.linkColor)
    .errorAlert(error: $viewModel.error)
    .task(id: ObjectIdentifier(viewModel)) {
      viewModel.fetchData()
    }
    .sheet(item: $viewModel.pendingImportBatch) { batch in
      ExternalImportView(
        initModel: {
          ExternalImportViewModel(batch: batch) { resources in
            viewModel.confirmExternalImport(resources)
          }
        }
      )
      .presentationBackground(.clear)
      .environmentObject(theme)
    }
    .onDisappear {
      viewModel.cancelFetchData()
    }
    .scrollIndicators(.hidden)
  }
  
  @ViewBuilder
  private var SmallDownloadButton: some View {
    Button {
      do {
        try viewModel.beginDownloadAudiobook(viewModel.item)
        onDownloadTap()
      } catch {
        viewModel.error = error
      }
    } label: {
      HStack {
        Image(systemName: "square.and.arrow.down")
      }
      .accessibilityLabel("download_title".localized)
      .frame(width: 36, height: 24)
      .padding()
      .foregroundStyle(theme.primaryColor)
      .background(theme.tertiarySystemBackgroundColor)
      .cornerRadius(10)
    }
  }
  
  @ViewBuilder
  private var SynchronizeButton: some View {
    Button {
      if viewModel.allowStream {
        Task {
          do {
            // No onDownloadTap() here: this stages pendingImportBatch for the
            // confirmation sheet below, and dismissing the browser would tear that
            // sheet down before it could present. confirmExternalImport deliberately
            // keeps you in the browser afterwards.
            try await self.viewModel.handleImportAudiobook(viewModel.item)
          } catch {
            viewModel.error = error
          }
        }
      } else {
        viewModel.goToSubscribe()
      }
    } label: {
      HStack {
        Image(systemName: "arrow.down.circle.dotted")
        Text("stream_button".localized)
          .bpFont(.title)
      }
      .frame(height: 24)
      .frame(maxWidth: .infinity)
      .padding()
      // Set once for the label AND the symbol: systemBackgroundColor on linkColor is the
      // app's accent-filled button treatment (what the Download button this replaced used).
      // primaryColor is the main foreground colour and reads low-contrast on the accent.
      .foregroundStyle(theme.systemBackgroundColor)
      .background(theme.linkColor)
      .cornerRadius(10)
    }
  }
}
