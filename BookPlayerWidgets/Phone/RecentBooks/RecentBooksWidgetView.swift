//
//  RecentBooksWidgetView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 26/11/20.
//  Copyright © 2020 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import UIKit
import WidgetKit

struct BookView: View {
  var item: PlayableItem
  var titleColor: Color
  var theme: SimpleTheme
  var isPlaying: Bool

  var body: some View {
    let title = item.title
    let identifier = item.relativePath
    let pauseImage: String? = isPlaying ? "pause.fill" : nil

    let cachedImageURL = ArtworkService.getCachedImageURL(for: identifier)

    return VStack(spacing: 5) {
      ZStack {
        let uiImage =
          UIImage(contentsOfFile: cachedImageURL.path)
          ?? ArtworkService.generateDefaultArtwork(from: theme.linkColor)

        if let uiImage,
          WidgetUtils.isValidSize(image: uiImage)
        {
          Image(uiImage: uiImage)
            .resizable()
            .frame(minWidth: 60, maxWidth: 60, minHeight: 60, maxHeight: 60)
            .aspectRatio(1.0, contentMode: .fit)
            .cornerRadius(8.0)
        } else {
          Image(systemName: "photo.badge.exclamationmark.fill")
            .frame(width: 60, height: 60)
            .background(Color.gray.opacity(0.2))
            .foregroundStyle(Color.white)
            .cornerRadius(8.0)
        }

        if let pauseImage {
          Circle()
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .opacity(0.8)
          Image(systemName: pauseImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundStyle(.black)
            .frame(width: 11, height: 11)
        }
      }

      Text(title)
        .fontWeight(.semibold)
        .frame(height: 40, alignment: .leading)
        .foregroundStyle(titleColor)
        .font(.caption)
        .lineLimit(2)
        .multilineTextAlignment(.center)
    }
  }
}

struct RecentBooksWidgetView: View {
  @Environment(\.colorScheme) var colorScheme
  var entry: LastPlayedProvider.Entry

  var body: some View {
    let items = Array(entry.items.prefix(4))

    let widgetColors = WidgetUtils.getColors(from: entry.theme, with: colorScheme)

    let appIconName = WidgetUtils.getAppIconName()

    return VStack(spacing: 3) {
      HStack {
        Text("Recent Books")
          .foregroundStyle(widgetColors.primaryColor)
          .font(.subheadline)
          .fontWeight(.semibold)
        Spacer()
        Image(appIconName)
          .accessibility(hidden: true)
          .frame(width: 28, height: 28)
          .padding([.trailing], 10)
          .cornerRadius(8.0)
      }
      .padding([.leading])
      .padding([.trailing, .bottom], 5)
      .padding([.top], 8)
      HStack {
        ForEach(items, id: \.relativePath) { item in
          if #available(iOSApplicationExtension 17.0, iOS 17.0, *) {
            Button(intent: BookPlaybackToggleIntent(relativePath: item.relativePath)) {
              BookView(
                item: item,
                titleColor: widgetColors.primaryColor,
                theme: entry.theme,
                isPlaying: item.relativePath == entry.currentlyPlaying
              )
              .frame(minWidth: 0, maxWidth: .infinity)
            }
            .buttonStyle(.plain)
          } else {
            BookView(
              item: item,
              titleColor: widgetColors.primaryColor,
              theme: entry.theme,
              isPlaying: item.relativePath == entry.currentlyPlaying
            )
            .frame(minWidth: 0, maxWidth: .infinity)
          }
        }
      }
      .padding([.leading, .trailing])

      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetBackground(backgroundView: widgetColors.backgroundColor)
  }
}

struct RecentBooksWidget: Widget {
  let kind: String = "com.bookplayer.widget.medium.recentBooks"

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: LastPlayedProvider(),
      content: { entry in
        RecentBooksWidgetView(entry: entry)
      }
    )
    .configurationDisplayName("Recent Books")
    .description("See the recent played books")
    .supportedFamilies([.systemMedium])
    .contentMarginsDisabledIfAvailable()
  }
}

extension SimpleLibraryItem {
  /// Convenience init for SwftUI previews and placeholders
  static public func previewItem(title: String) -> Self {
    SimpleLibraryItem(
      title: title,
      details: "Author",
      speed: 1,
      currentTime: 1,
      duration: 1,
      percentCompleted: 10,
      isFinished: false,
      relativePath: UUID().uuidString,
      remoteURL: nil,
      artworkURL: nil,
      orderRank: 1,
      parentFolder: nil,
      originalFileName: "",
      lastPlayDate: nil,
      type: SimpleItemType.book
    )
  }
}
