//
//  JellyfinAudiobookDetailsView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Kingfisher
import SwiftUI

struct JellyfinAudiobookDetailsViewModel {
  let item: JellyfinLibraryItem
}

struct JellyfinAudiobookDetailsView<LibraryVM: JellyfinLibraryViewModelProtocol>: View {
  let viewModel: JellyfinAudiobookDetailsViewModel
  @StateObject private var themeViewModel = ThemeViewModel()
  @EnvironmentObject var libraryVM: LibraryVM
  
  var body: some View {
    VStack {
      Text(viewModel.item.name)
        .font(.title)
      
      JellyfinLibraryItemImageView<LibraryVM>(item: viewModel.item)
      
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
  }
}

#Preview {
  let item = JellyfinLibraryItem(id: "0", name: "Mock Audiobook", kind: .audiobook)
  let parentData = JellyfinLibraryLevelData.topLevel(libraryName: "Mock Library", userID: "42")
  JellyfinAudiobookDetailsView<MockJellyfinLibraryViewModel>(viewModel: JellyfinAudiobookDetailsViewModel(item: item))
  .environmentObject(MockJellyfinLibraryViewModel(data: parentData))
}
