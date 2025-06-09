//
//  JellyfinAudiobookDetailsView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Kingfisher
import SwiftUI
import BookPlayerKit

struct JellyfinAudiobookDetailsView<
  Model: JellyfinAudiobookDetailsViewModelProtocol
>: View {

  @StateObject var viewModel: Model
  @StateObject private var themeViewModel = ThemeViewModel()
  @State var filePathLineLimit: Int? = 1

  var onDownloadTap: (() -> Void)

  var body: some View {
    VStack {
      if let artist = viewModel.details?.artist {
        Text(artist)
          .font(.title2)
          .foregroundColor(themeViewModel.secondaryColor)
          .lineLimit(1)
      }

      Text(viewModel.item.name)
        .font(.title)

      JellyfinLibraryItemImageView(
        item: viewModel.item,
        connectionService: viewModel.connectionService
      )

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
          }
          HStack {
            Text(details.runtimeString)
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
