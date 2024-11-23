//
//  JellyfinLibraryItemView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-28.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI
import Kingfisher

struct JellyfinLibraryItemImageView<Model: JellyfinLibraryViewModelProtocol>: View {
  @State var item: JellyfinLibraryItem
  @EnvironmentObject var viewModel: Model
  @Environment(\.displayScale) private var displayScale

  var body: some View {
    let aspectRatio: CGFloat? = if let v = item.imageAspectRatio { CGFloat(v) } else { nil }

    GeometryReader { proxy in
      let imageSize = CGSize(width: proxy.size.width * displayScale, height: proxy.size.height * displayScale)

      KFImage
        .url(viewModel.createItemImageURL(item, size: imageSize))
        .cancelOnDisappear(true)
        .cacheMemoryOnly()
        .resizable()
        .placeholder { placeholderImage(aspectRatio: aspectRatio) }
        .fade(duration: 0.5)
    }
    .aspectRatio(aspectRatio, contentMode: .fit)
    .cornerRadius(3)
  }

  @ViewBuilder
  private func placeholderImage(aspectRatio: CGFloat?) -> some View {
    let image = if let blurHashImage = blurhashImage {
      Image(uiImage: blurHashImage)
    } else {
      Image(systemName: placeholderImageName)
    }

    image
      .resizable()
      .aspectRatio(aspectRatio, contentMode: .fit)
  }

  private var blurhashImage: UIImage? {
    guard let blurHash = item.blurHash  else { return nil }
    return UIImage(blurHash: blurHash, size: CGSize(width: 16, height: 16))
  }

  private var placeholderImageName: String {
    switch item.kind {
    case .userView, .folder: "folder"
    case .audiobook: "headphones"
    }
  }
}

#Preview("audiobook") {
  let parentData = JellyfinLibraryLevelData.topLevel(libraryName: "Mock Library", userID: "42")
  JellyfinLibraryItemImageView<MockJellyfinLibraryViewModel>(item: JellyfinLibraryItem(id: "0.0", name: "An audiobook", kind: .audiobook))
    .environmentObject(MockJellyfinLibraryViewModel(data: parentData))
}
