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

  /// Browsing covers (folders, libraries, authors, narrators) are downloaded as
  /// low-res thumbnails so navigating large folders stays snappy. Audiobook covers
  /// stay full-res because they're shown larger and at the details screen.
  private var isThumbnail: Bool {
    switch item.kind {
    case .audiobook: false
    case .folder, .userView, .author, .narrator: true
    }
  }

  var body: some View {
    let aspectRatio: CGFloat? = if let v = item.imageAspectRatio { CGFloat(v) } else { nil }

    GeometryReader { proxy in
      let hasSize = proxy.size.width > 0 && proxy.size.height > 0
      let imageSize = IntegrationImageSizing.bucketedSize(
        for: proxy.size,
        displayScale: displayScale,
        isThumbnail: isThumbnail
      )
      JellyfinLibraryItemImageViewWrapper(
        item: item,
        url: hasSize
          ? (try? connectionService.createItemImageURL(
            item,
            size: imageSize,
            quality: isThumbnail ? 70 : nil
          ))
          : nil,
        customHeaders: connectionService.connection?.customHeaders ?? [:],
        imageSize: imageSize,
        aspectRatio: aspectRatio
      )
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .aspectRatio(aspectRatio, contentMode: .fit)
  }
}

/// Utility for JellyfinLibraryItemImageView to avoid reloading the image when the size changes
fileprivate struct JellyfinLibraryItemImageViewWrapper: View, Equatable {
  let item: JellyfinLibraryItem
  let url: URL?
  let customHeaders: [String: String]
  let imageSize: CGSize
  let aspectRatio: CGFloat?

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    KFImage
      .url(url)
      .requestModifier(AnyModifier { request in
        var request = request
        for (key, value) in customHeaders
        where key.caseInsensitiveCompare("Authorization") != .orderedSame {
          request.setValue(value, forHTTPHeaderField: key)
        }
        return request
      })
      .cancelOnDisappear(true)
      .resizable()
      .placeholder { placeholderImageView(aspectRatio: aspectRatio) }
      .fade(duration: 0.5)
  }
  
  static func == (lhs: Self, rhs: Self) -> Bool {
    return lhs.item.id == rhs.item.id
      && lhs.url == rhs.url
      && lhs.customHeaders == rhs.customHeaders
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
    item.placeholderImageName
  }
}

#Preview("audiobook") {
  JellyfinLibraryItemImageView(item: JellyfinLibraryItem(id: "0.0", name: "An audiobook", kind: .audiobook))
    .environmentObject(ThemeViewModel())
}
