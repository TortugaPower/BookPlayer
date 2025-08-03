//
//  JellyfinLibraryItemImageView.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-10-28.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import Kingfisher
import BookPlayerKit

struct JellyfinLibraryItemImageView: View {
  let item: JellyfinLibraryItem
  @Environment(\.jellyfinService) var connectionService: JellyfinConnectionService
  @Environment(\.displayScale) private var displayScale

  var body: some View {
    let aspectRatio: CGFloat? = if let v = item.imageAspectRatio { CGFloat(v) } else { nil }

    GeometryReader { proxy in
      let imageSize = CGSize(width: proxy.size.width * displayScale, height: proxy.size.height * displayScale)
      JellyfinLibraryItemImageViewWrapper(
        item: item,
        url: try? connectionService.createItemImageURL(item, size: imageSize),
        imageSize: imageSize,
        aspectRatio: aspectRatio
      )
      .cornerRadius(max(3, min(proxy.size.width, proxy.size.height) * 0.02))
    }
    .aspectRatio(aspectRatio, contentMode: .fit)
  }
}

/// Utility for JellyfinLibraryItemImageView to avoid reloading the image when the size changes
fileprivate struct JellyfinLibraryItemImageViewWrapper: View, Equatable {
  let item: JellyfinLibraryItem
  let url: URL?
  let imageSize: CGSize
  let aspectRatio: CGFloat?

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    KFImage
      .url(url)
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
    if let blurHashImage = blurhashImageView {
      Image(uiImage: blurHashImage)
        .resizable()
        .aspectRatio(aspectRatio, contentMode: .fit)
    } else {
      ZStack {
        themeViewModel.linkColor
        Image(systemName: placeholderImageName)
          .resizable()
          .foregroundStyle(.white)
          .aspectRatio(contentMode: .fit)
          .padding()
          .frame(maxWidth: 200)
      }
    }
  }
  
  private var blurhashImageView: UIImage? {
    guard let blurHash = item.blurHash  else { return nil }
    return UIImage(blurHash: blurHash, size: CGSize(width: 16, height: 16))
  }
  
  private var placeholderImageName: String {
    switch item.kind {
    case .userView, .folder: "folder"
    case .audiobook: "waveform"
    }
  }
}

#Preview("audiobook") {
  JellyfinLibraryItemImageView(item: JellyfinLibraryItem(id: "0.0", name: "An audiobook", kind: .audiobook))
    .environmentObject(ThemeViewModel())
}
