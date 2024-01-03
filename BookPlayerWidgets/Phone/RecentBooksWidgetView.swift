//
//  RecentBooksWidgetView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 26/11/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct RecentBooksProvider: TimelineProvider {
  let numberOfBooks = 4

  typealias Entry = LibraryEntry

  func placeholder(in context: Context) -> LibraryEntry {
    return LibraryEntry(
      date: Date(),
      items: [
        SimpleLibraryItem.previewItem(title: "Last played"),
        SimpleLibraryItem.previewItem(title: "Book title"),
        SimpleLibraryItem.previewItem(title: "Book title"),
        SimpleLibraryItem.previewItem(title: "Book title")
      ]
    )
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (LibraryEntry) -> Void
  ) {
    Task {
      do {
        let entry = try await getEntryForTimeline(
          context: context
        )
        completion(entry)
      } catch {
        completion(placeholder(in: context))
      }
    }
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<LibraryEntry>) -> Void
  ) {
    Task {
      do {
        let entry = try await getEntryForTimeline(context: context)

        completion(Timeline(entries: [entry], policy: .never))
      } catch {
        completion(Timeline(entries: [], policy: .never))
      }
    }
  }

  func getEntryForTimeline(context: Context) async throws -> LibraryEntry {
    let stack = try await DatabaseInitializer().loadCoreDataStack()
    let dataManager = DataManager(coreDataStack: stack)
    let libraryService = LibraryService(dataManager: dataManager)

    guard
      let items = libraryService.getLastPlayedItems(limit: numberOfBooks)
    else {
      throw BookPlayerError.emptyResponse
    }

    let theme = libraryService.getLibraryCurrentTheme() ?? SimpleTheme.getDefaultTheme()

    let entry = LibraryEntry(
      date: Date(),
      items: items,
      theme: theme
    )

    return entry
  }
}

struct BookView: View {
  var item: SimpleLibraryItem
  var titleColor: Color
  var theme: SimpleTheme?
  var entry: RecentBooksProvider.Entry

  var body: some View {
    let title = item.title
    let identifier = item.relativePath

    let cachedImageURL = ArtworkService.getCachedImageURL(for: identifier)

    return VStack(spacing: 5) {
      Image(uiImage: UIImage(contentsOfFile: cachedImageURL.path)
            ?? ArtworkService.generateDefaultArtwork(from: entry.theme.linkColor)!)
      .resizable()
      .frame(minWidth: 60, maxWidth: 60, minHeight: 60, maxHeight: 60)
      .aspectRatio(1.0, contentMode: .fit)
      .cornerRadius(8.0)

      Text(title)
        .fontWeight(.semibold)
        .frame(height: 40, alignment: .leading)
        .foregroundColor(titleColor)
        .font(.caption)
        .lineLimit(2)
        .multilineTextAlignment(.center)
    }
  }
}

struct RecentBooksWidgetView: View {
  @Environment(\.colorScheme) var colorScheme
  var entry: RecentBooksProvider.Entry

  var body: some View {
    let items = Array(entry.items.prefix(4))

    let widgetColors = WidgetUtils.getColors(from: entry.theme, with: colorScheme)

    let appIconName = WidgetUtils.getAppIconName()

    return VStack(spacing: 3) {
      HStack {
        Text("Recent Books")
          .foregroundColor(widgetColors.primaryColor)
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
            Button(intent: BookStartPlaybackIntent(relativePath: item.relativePath)) {
              BookView(
                item: item,
                titleColor: widgetColors.primaryColor,
                theme: entry.theme,
                entry: entry
              )
              .frame(minWidth: 0, maxWidth: .infinity)
            }
            .buttonStyle(.plain)
          } else {
            BookView(
              item: item,
              titleColor: widgetColors.primaryColor,
              theme: entry.theme,
              entry: entry
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

struct RecentBooksWidgetView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      RecentBooksWidgetView(entry: LibraryEntry(
        date: Date(),
        items: [
          .previewItem(title: "a very very very long title"),
          .previewItem(title: "a short title"),
          .previewItem(title: "a short title"),
          .previewItem(title: "a short title")
        ]))
      .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
  }
}

struct RecentBooksWidget: Widget {
  let kind: String = "com.bookplayer.widget.medium.recentBooks"

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: RecentBooksProvider(),
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
      type: SimpleItemType.book)
  }
}
