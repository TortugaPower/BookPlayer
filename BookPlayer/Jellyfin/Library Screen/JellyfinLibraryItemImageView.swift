//
//  JellyfinLibraryItemView.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-28.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI
import Kingfisher

struct JellyfinLibraryItemImageView<Model: JellyfinLibraryFolderViewModelProtocol>: View {
  @State var item: JellyfinLibraryItem
  @EnvironmentObject var viewModel: Model

  var body: some View {
    KFImage
      .url(viewModel.createItemImageURL(item))
      .cancelOnDisappear(true)
      .cacheMemoryOnly()
      .resizable()
      .placeholder { placeholderImage }
      .fade(duration: 0.25)
      .aspectRatio(contentMode: .fit)
      .frame(width: 100, height: 100)
      .cornerRadius(3)
  }

  @ViewBuilder
  private var placeholderImage: some View {
    let image = if let blurHashImage = blurhashImage {
      Image(uiImage: blurHashImage)
    } else {
      Image(systemName: placeholderImageName)
    }

    image
      .resizable()
      .aspectRatio(item.imageAspectRatio, contentMode: .fit)
  }

  private var blurhashImage: UIImage? {
    guard let blurHash = item.blurHash  else { return nil }
    return UIImage(blurHash: blurHash, size: CGSize(width: 32, height: 32))
  }

  private var placeholderImageName: String {
    switch item.kind {
    case .userView, .folder: "folder"
    case .audiobook: "headphones"
    }
  }
}

#Preview("audiobook") {
  JellyfinLibraryItemImageView<MockJellyfinLibraryFolderViewModel>(item: JellyfinLibraryItem(id: "0.0", name: "An audiobook", kind: .audiobook))
    .environmentObject(MockJellyfinLibraryFolderViewModel(data: JellyfinLibraryItem(id: "0", name: "Parent", kind: .folder)))
}
