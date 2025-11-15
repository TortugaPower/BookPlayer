//
//  AudiobookShelfAudiobookDetailsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import SwiftUI

struct AudiobookShelfAudiobookDetailsView<
  Model: AudiobookShelfAudiobookDetailsViewModelProtocol
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
      return viewModel.item.title
    }

    return VoiceOverService.playerMetaText(
      title: viewModel.item.title,
      author: details.artist ?? "voiceover_unknown_author".localized
    )
  }

  var body: some View {
    ScrollView {
      VStack {
        AudiobookShelfLibraryItemImageView(item: viewModel.item)
          .environment(\.audiobookshelfService, viewModel.connectionService)
          .accessibilityHidden(true)
          .padding(.horizontal, Spacing.L1)

        Text(viewModel.item.title)
          .font(.title)
          .accessibilityLabel(voiceOverBookInfo)
          .foregroundStyle(theme.primaryColor)
          .multilineTextAlignment(.center)

        if let artist = viewModel.details?.artist {
          Text(artist)
            .font(.title2)
            .foregroundStyle(theme.secondaryColor)
            .lineLimit(1)
            .accessibilityHidden(true)
        }

        if let narrator = viewModel.details?.narrator, !narrator.isEmpty {
          Text("Narrated by \(narrator)")
            .font(.subheadline)
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
          .font(.caption)
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

        if let details = viewModel.details {
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
              AudiobookShelfTagsView(tags: genres)
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
              AudiobookShelfTagsView(tags: tags)
            }
          }

          if let series = details.series,
            !series.isEmpty
          {
            DisclosureGroup("Series", isExpanded: .constant(true)) {
              VStack(alignment: .leading, spacing: 8) {
                ForEach(series, id: \.self) { item in
                  Text(item.name)
                }
              }
            }
          }
        }
      }
    }
    .tint(theme.linkColor)
    .errorAlert(error: $viewModel.error)
    .padding()
    .onAppear {
      viewModel.fetchData()
    }
    .onDisappear {
      viewModel.cancelFetchData()
    }
    .scrollIndicators(.hidden)
  }
}

final class MockAudiobookShelfAudiobookDetailsViewModel: AudiobookShelfAudiobookDetailsViewModelProtocol {
  var connectionService = AudiobookShelfConnectionService()

  let item: AudiobookShelfLibraryItem
  let details: AudiobookShelfAudiobookDetailsData?
  var error: Error?

  init(item: AudiobookShelfLibraryItem, details: AudiobookShelfAudiobookDetailsData?) {
    self.item = item
    self.details = details
  }

  @MainActor
  func fetchData() {}

  @MainActor
  func cancelFetchData() {}

  @MainActor
  func beginDownloadAudiobook(_ item: AudiobookShelfLibraryItem) {}
}

#Preview {
  let item = AudiobookShelfLibraryItem(
    id: "0.1",
    title: "The Great Gatsby",
    kind: .audiobook,
    libraryId: "1"
  )
  let details = AudiobookShelfAudiobookDetailsData(
    artist: "F. Scott Fitzgerald",
    narrator: "Jake Gyllenhaal",
    filePath: "/audiobooks/The Great Gatsby/The Great Gatsby.m4b",
    fileSize: 189_678_390,
    overview:
      "The Great Gatsby is a 1925 novel by American writer F. Scott Fitzgerald. Set in the Jazz Age on Long Island, near New York City, the novel depicts first-person narrator Nick Carraway's interactions with mysterious millionaire Jay Gatsby and Gatsby's obsession to reunite with his former lover, Daisy Buchanan.",
    runtimeInSeconds: 14580.5,
    genres: ["Classic", "Fiction"],
    tags: ["American Literature", "1920s"],
    publishedYear: nil,
    publisher: nil,
    series: [.init(id: "1", name: "The Great American Novels", sequence: nil)]
  )
  let parentData = AudiobookShelfLibraryLevelData.topLevel(libraryName: "Mock Library")
  let vm = MockAudiobookShelfAudiobookDetailsViewModel(item: item, details: details)
  AudiobookShelfAudiobookDetailsView<MockAudiobookShelfAudiobookDetailsViewModel>(viewModel: vm, onDownloadTap: {})
    .environmentObject(MockAudiobookShelfLibraryViewModel(data: parentData))
    .environmentObject(ThemeViewModel())
}
