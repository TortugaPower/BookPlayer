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

  /// Browsing covers (collections, etc.) are downloaded as low-res thumbnails so
  /// navigating large libraries stays snappy. Audiobook/podcast covers stay full-res
  /// because they're shown larger and again on the details screen.
  private var isThumbnail: Bool {
    !item.isDownloadable
  }

  var body: some View {
    GeometryReader { proxy in
      let imageSize = IntegrationImageSizing.bucketedSize(
        width: proxy.size.width,
        height: proxy.size.height,
        displayScale: displayScale,
        isThumbnail: isThumbnail
      )
      AudiobookShelfLibraryItemImageViewWrapper(
        item: item,
        url: connectionService.createItemImageURL(item, size: imageSize),
        apiToken: connectionService.connection?.apiToken,
        customHeaders: connectionService.connection?.customHeaders ?? [:],
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
  let apiToken: String?
  let customHeaders: [String: String]
  let imageSize: CGSize

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    KFImage
      .url(url)
      .requestModifier(AnyModifier { request in
        var request = request
        for (key, value) in customHeaders {
          request.setValue(value, forHTTPHeaderField: key)
        }
        if let apiToken {
          request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        }
        return request
      })
      .cancelOnDisappear(true)
      .resizable()
      .placeholder { placeholderImageView() }
      .fade(duration: 0.5)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.item.id == rhs.item.id
      && lhs.url == rhs.url
      && lhs.apiToken == rhs.apiToken
      && lhs.customHeaders == rhs.customHeaders
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
    item.placeholderImageName
  }
}
