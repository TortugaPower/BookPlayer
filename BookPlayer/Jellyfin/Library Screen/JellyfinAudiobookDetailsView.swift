//
//  JellyfinAudiobookDetailsView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Kingfisher
import SwiftUI

struct JellyfinAudiobookDetailsView<Model: JellyfinAudiobookDetailsViewModelProtocol, LibraryVM: JellyfinLibraryViewModelProtocol>: View {
  @ObservedObject var viewModel: Model
  @EnvironmentObject var libraryVM: LibraryVM
  @StateObject private var themeViewModel = ThemeViewModel()
  @State var filePathLineLimit: Int? = 1
  
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
      
      JellyfinLibraryItemImageView<LibraryVM>(item: viewModel.item)
      
      if let details = viewModel.details {
        VStack {
          if let filePath = details.filePath {
            Text(filePath)
              .lineLimit(filePathLineLimit)
              .truncationMode(.middle)
              .onTapGesture {
                filePathLineLimit = (filePathLineLimit == nil) ? 1 : nil
              }
              .padding([.bottom])
          }
          HStack {
            Text(details.runtimeString)
            Spacer()
            Text(details.fileSizeString)
          }
        }
        .padding()
        .foregroundColor(themeViewModel.secondaryColor)
      }
      
      Spacer()
      
      Button {
        libraryVM.beginDownloadAudiobook(viewModel.item)
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
    .padding()
    .toolbar {
      ToolbarItemGroup(placement: .topBarTrailing) {
        Button(
          action: libraryVM.handleDoneAction,
          label: {
            Image(systemName: "xmark")
              .foregroundColor(themeViewModel.linkColor)
          }
        )
      }
    }
    .onAppear {
      viewModel.fetchData()
    }
    .onDisappear {
      viewModel.cancelFetchData()
    }
  }
}

final class MockJellyfinAudiobookDetailsViewModel: JellyfinAudiobookDetailsViewModelProtocol {
  let item: JellyfinLibraryItem
  let details: JellyfinAudiobookDetailsData?
  
  init(item: JellyfinLibraryItem, details: JellyfinAudiobookDetailsData?) {
    self.item = item
    self.details = details
  }
  
  @MainActor
  func fetchData() {}

  @MainActor
  func cancelFetchData() {}
}

#Preview {
  let item = JellyfinLibraryItem(id: "0", name: "Mock Audiobook", kind: .audiobook)
  let details = JellyfinAudiobookDetailsData(
    artist: "The Author's Name",
    filePath: "/path/to/file/which/might/be/very/very/very/very/very/very/very/very/very/very/very/very/very/very/long/actually.m4a",
    fileSize: 18967839,
    runtimeInSeconds: 580.1737409)
  let parentData = JellyfinLibraryLevelData.topLevel(libraryName: "Mock Library", userID: "42")
  let vm = MockJellyfinAudiobookDetailsViewModel(item: item, details: details)
  JellyfinAudiobookDetailsView<MockJellyfinAudiobookDetailsViewModel, MockJellyfinLibraryViewModel>(viewModel: vm)
    .environmentObject(MockJellyfinLibraryViewModel(data: parentData))
}
