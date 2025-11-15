//
//  AudiobookShelfLibraryItemImageView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import Kingfisher
import BookPlayerKit

struct AudiobookShelfLibraryItemImageView: View {
  let item: AudiobookShelfLibraryItem
  @Environment(\.audiobookshelfService) var connectionService: AudiobookShelfConnectionService
  @Environment(\.displayScale) private var displayScale

  var body: some View {
    GeometryReader { proxy in
      let imageSize = CGSize(width: proxy.size.width * displayScale, height: proxy.size.height * displayScale)
      AudiobookShelfLibraryItemImageViewWrapper(
        item: item,
        url: connectionService.createItemImageURL(item, size: imageSize),
        imageSize: imageSize
      )
      .cornerRadius(max(3, min(proxy.size.width, proxy.size.height) * 0.02))
    }
    .aspectRatio(1.0, contentMode: .fit)
  }
}

/// Utility for AudiobookShelfLibraryItemImageView to avoid reloading the image when the size changes
fileprivate struct AudiobookShelfLibraryItemImageViewWrapper: View, Equatable {
  let item: AudiobookShelfLibraryItem
  let url: URL?
  let imageSize: CGSize

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    KFImage
      .url(url)
      .cancelOnDisappear(true)
      .cacheMemoryOnly()
      .resizable()
      .placeholder { placeholderImageView() }
      .fade(duration: 0.5)
  }
  
  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.item.kind == rhs.item.kind && lhs.item.id == rhs.item.id
  }
  
  @ViewBuilder
  private func placeholderImageView() -> some View {
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

  private var placeholderImageName: String {
    switch item.kind {
    case .podcast, .audiobook: "waveform"
    case .library: "folder"
    }
  }
}
