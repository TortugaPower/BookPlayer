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

  var showSubscribeButton: Bool = false
  var allowStream: Bool = false
  var onDownloadTap: () -> Void
  var onStreamTap: () -> Void
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
          Text("Narrated by \(narrator)")
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

        HStack(spacing: 12) {
          if allowStream {
            SynchronizeButton
          } else if showSubscribeButton {
            SmallDownloadButton
            SynchronizeButton
          } else {
            DownloadButton
          }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)

        if let details = viewModel.details {
          VStack {
            if let filePath = details.filePath {
              DisclosureGroup("File Path", isExpanded: $isFilePathExpanded) {
                Text(filePath)
              }
              .accessibilityHidden(true)
            }

            if let genres = details.genres, !genres.isEmpty {
              DisclosureGroup("Genres", isExpanded: $isGenresExpanded) {
                IntegrationTagsView(tags: genres)
              }
            }

            if let overview = details.overview {
              DisclosureGroup("Overview", isExpanded: $isOverviewExpanded) {
                Text(overview)
              }
            }

            if let tags = details.tags, !tags.isEmpty {
              DisclosureGroup("Tags", isExpanded: $isTagsExpanded) {
                IntegrationTagsView(tags: tags)
              }
            }

            if !details.seriesEntries.isEmpty {
              DisclosureGroup("Series", isExpanded: .constant(true)) {
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
    .onAppear {
      viewModel.fetchData()
    }
    .onDisappear {
      viewModel.cancelFetchData()
    }
    .scrollIndicators(.hidden)
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
        Text("Download 2")
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
      if allowStream {
        do {
          try self.viewModel.handleImportAudiobook(viewModel.item)
          onDownloadTap()
        } catch {
          viewModel.error = error
        }
      } else {
        onStreamTap()
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
