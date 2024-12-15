//
//  JellyfinLibraryItemView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-28.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI
import Kingfisher

struct JellyfinLibraryItemImageView<LibraryVM: JellyfinLibraryViewModelProtocol>: View {
  let item: JellyfinLibraryItem
  @Environment(\.displayScale) private var displayScale
  
  var body: some View {
    let aspectRatio: CGFloat? = if let v = item.imageAspectRatio { CGFloat(v) } else { nil }
    
    GeometryReader { proxy in
      let imageSize = CGSize(width: proxy.size.width * displayScale, height: proxy.size.height * displayScale)
      JellyfinLibraryItemImageViewWrapper<LibraryVM>(item: item,
                                                     imageSize: imageSize,
                                                     aspectRatio: aspectRatio)
      .cornerRadius(max(3, min(proxy.size.width, proxy.size.height) * 0.02))
    }
    .aspectRatio(aspectRatio, contentMode: .fit)
  }
}

/// Utility for JellyfinLibraryItemImageView to avoid reloading the image when the size changes
fileprivate struct JellyfinLibraryItemImageViewWrapper<LibraryVM: JellyfinLibraryViewModelProtocol>: View, Equatable {
  let item: JellyfinLibraryItem
  let imageSize: CGSize
  let aspectRatio: CGFloat?
  @EnvironmentObject var libraryVM: LibraryVM
  
  var body: some View {
    KFImage
      .url(libraryVM.createItemImageURL(item, size: imageSize))
      .cancelOnDisappear(true)
      .cacheMemoryOnly()
      .resizable()
      .placeholder { placeholderImageView(aspectRatio: aspectRatio) }
      .fade(duration: 0.5)
  }
  
  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.item.kind == rhs.item.kind && lhs.item.id == rhs.item.id
  }
  
  @ViewBuilder
  private func placeholderImageView(aspectRatio: CGFloat?) -> some View {
    let image = if let blurHashImage = blurhashImageView {
      Image(uiImage: blurHashImage)
    } else {
      Image(systemName: placeholderImageName)
    }
    
    image
      .resizable()
      .aspectRatio(aspectRatio, contentMode: .fit)
  }
  
  private var blurhashImageView: UIImage? {
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
