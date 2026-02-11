//
//  JellyfinAudiobookDetailsView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import SwiftUI

struct JellyfinAudiobookDetailsView<
  Model: JellyfinAudiobookDetailsViewModelProtocol
>: View {

  @State private var isFilePathExpanded: Bool = false
  @State private var isGenresExpanded: Bool = false
  @State private var isOverviewExpanded: Bool = true
  @State private var isTagsExpanded: Bool = true
  @StateObject var viewModel: Model
  @EnvironmentObject private var theme: ThemeViewModel
  @State var filePathLineLimit: Int? = 1

  var onDownloadTap: (() -> Void)

  var voiceOverBookInfo: String {
    guard let details = viewModel.details else {
      return viewModel.item.name
    }

    return VoiceOverService.playerMetaText(
      title: viewModel.item.name,
      author: details.artist ?? "voiceover_unknown_author".localized
    )
  }

  var body: some View {
    ScrollView {
      VStack {
        JellyfinLibraryItemImageView(item: viewModel.item)
          .environment(\.jellyfinService, viewModel.connectionService)
          .accessibilityHidden(true)
          .padding(.horizontal, Spacing.L1)

        Text(viewModel.item.name)
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
            Text("download_title".localized)
              .fontWeight(.semibold)
          }
          .frame(maxWidth: .infinity)
          .padding()
          .foregroundStyle(theme.systemBackgroundColor)
          .background(theme.linkColor)
          .cornerRadius(10)
        }
        .padding(.horizontal)

        if let details = viewModel.details {
          VStack {
            if let filePath = details.filePath {
              DisclosureGroup("File Path", isExpanded: $isFilePathExpanded) {
                Text(filePath)
              }
              .accessibilityHidden(true)
            }

            if let genres = details.genres,
              !genres.isEmpty
            {
              DisclosureGroup("Genres", isExpanded: $isGenresExpanded) {
                JellyfinTagsView(tags: genres)
              }
            }

            if let overview = details.overview {
              DisclosureGroup("Overview", isExpanded: $isOverviewExpanded) {
                Text(overview)
              }
            }

            if let tags = details.tags,
              !tags.isEmpty
            {
              DisclosureGroup("Tags", isExpanded: $isTagsExpanded) {
                JellyfinTagsView(tags: tags)
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
}

final class MockJellyfinAudiobookDetailsViewModel: JellyfinAudiobookDetailsViewModelProtocol {
  var connectionService = JellyfinConnectionService()

  let item: JellyfinLibraryItem
  let details: JellyfinAudiobookDetailsData?
  var error: Error?

  init(item: JellyfinLibraryItem, details: JellyfinAudiobookDetailsData?) {
    self.item = item
    self.details = details
  }

  @MainActor
  func fetchData() {}

  @MainActor
  func cancelFetchData() {}

  @MainActor
  func beginDownloadAudiobook(_ item: JellyfinLibraryItem) {}
}

#Preview {
  let item = JellyfinLibraryItem(id: "0", name: "Mock Audiobook", kind: .audiobook)
  let details = JellyfinAudiobookDetailsData(
    artist: "The Author's Name",
    filePath:
      "/path/to/file/which/might/be/very/very/very/very/very/very/very/very/very/very/very/very/very/very/long/actually.m4a",
    fileSize: 18_967_839,
    overview: "Overview",
    runtimeInSeconds: 580.1737409,
    genres: nil,
    tags: nil
  )
  let parentData = JellyfinLibraryLevelData.topLevel(libraryName: "Mock Library")
  let vm = MockJellyfinAudiobookDetailsViewModel(item: item, details: details)
  JellyfinAudiobookDetailsView<MockJellyfinAudiobookDetailsViewModel>(viewModel: vm, onDownloadTap: {})
    .environmentObject(MockJellyfinLibraryViewModel(data: parentData))
}
