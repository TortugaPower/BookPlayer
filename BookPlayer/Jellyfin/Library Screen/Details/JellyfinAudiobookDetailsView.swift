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

  @StateObject var viewModel: Model
  @StateObject private var themeViewModel = ThemeViewModel()
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
    VStack {
      if let artist = viewModel.details?.artist {
        Text(artist)
          .font(.title2)
          .foregroundColor(themeViewModel.secondaryColor)
          .lineLimit(1)
          .accessibilityHidden(true)
      }

      Text(viewModel.item.name)
        .font(.title)
        .accessibilityLabel(voiceOverBookInfo)

      JellyfinLibraryItemImageView(item: viewModel.item)
        .environmentObject(themeViewModel)
        .environmentObject(viewModel.connectionService)
        .accessibilityHidden(true)

      if let details = viewModel.details {
        VStack {
          if let filePath = details.filePath {
            Text(filePath)
              .lineLimit(filePathLineLimit)
              .truncationMode(.middle)
              .onTapGesture {
                filePathLineLimit = (filePathLineLimit == nil) ? 1 : nil
              }
              .padding(.bottom, 8)
              .accessibilityHidden(true)
          }
          HStack {
            Text(details.runtimeString)
              .accessibilityLabel("book_duration_title".localized + details.runtimeString)
            Spacer()
            Text(details.fileSizeString)
          }

          if let overview = details.overview {
            Text(overview)
              .lineLimit(nil)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.top, 8)
          }
        }
        .padding([.horizontal, .bottom])
        .foregroundColor(themeViewModel.secondaryColor)
      }

      Spacer()

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
        .foregroundColor(themeViewModel.systemBackgroundColor)
        .background(themeViewModel.linkColor)
        .cornerRadius(10)
      }
    }
    .errorAlert(error: $viewModel.error)
    .padding()
    .onAppear {
      viewModel.fetchData()
    }
    .onDisappear {
      viewModel.cancelFetchData()
    }
  }
}

final class MockJellyfinAudiobookDetailsViewModel: JellyfinAudiobookDetailsViewModelProtocol {
  var connectionService = JellyfinConnectionService(keychainService: KeychainService())

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
    runtimeInSeconds: 580.1737409
  )
  let parentData = JellyfinLibraryLevelData.topLevel(libraryName: "Mock Library")
  let vm = MockJellyfinAudiobookDetailsViewModel(item: item, details: details)
  JellyfinAudiobookDetailsView<MockJellyfinAudiobookDetailsViewModel>(viewModel: vm, onDownloadTap: {})
    .environmentObject(MockJellyfinLibraryViewModel(data: parentData))
}
