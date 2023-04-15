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

struct RecentBooksProvider: IntentTimelineProvider {
    let numberOfBooks = 4

    typealias Entry = LibraryEntry

    func placeholder(in context: Context) -> LibraryEntry {
      return LibraryEntry(date: Date(), items: [], theme: nil, timerSeconds: 300, autoplay: true)
    }

  func getSnapshot(for configuration: PlayAndSleepActionIntent, in context: Context, completion: @escaping (LibraryEntry) -> Void) {
    let stack = DataMigrationManager().getCoreDataStack()
    stack.loadStore { _, error in
      guard error == nil else {
        completion(self.placeholder(in: context))
        return
      }

      let dataManager = DataManager(coreDataStack: stack)
      let libraryService = LibraryService(dataManager: dataManager)

      guard let items = libraryService.getLastPlayedItems(limit: self.numberOfBooks),
            let currentTheme = try? libraryService.getLibraryCurrentTheme() else {
              completion(self.placeholder(in: context))
              return
            }

      let theme = SimpleTheme(with: currentTheme)

      let autoplay = configuration.autoplay?.boolValue ?? true
      let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

      let entry = LibraryEntry(date: Date(),
                               items: items,
                               theme: theme,
                               timerSeconds: seconds,
                               autoplay: autoplay)

      completion(entry)
    }
  }

  func getTimeline(for configuration: PlayAndSleepActionIntent, in context: Context, completion: @escaping (Timeline<LibraryEntry>) -> Void) {
    let stack = DataMigrationManager().getCoreDataStack()
    stack.loadStore { _, error in
      guard error == nil else {
        completion(Timeline(entries: [], policy: .atEnd))
        return
      }

      let dataManager = DataManager(coreDataStack: stack)
      let libraryService = LibraryService(dataManager: dataManager)

      guard let items = libraryService.getLastPlayedItems(limit: self.numberOfBooks),
            let currentTheme = try? libraryService.getLibraryCurrentTheme() else {
              completion(Timeline(entries: [], policy: .atEnd))
              return
            }

      let theme = SimpleTheme(with: currentTheme)

      let autoplay = configuration.autoplay?.boolValue ?? true
      let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

      let entry = LibraryEntry(date: Date(),
                               items: items,
                               theme: theme,
                               timerSeconds: seconds,
                               autoplay: autoplay)

      completion(Timeline(entries: [entry], policy: .atEnd))
    }
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

    let url = WidgetUtils.getWidgetActionURL(with: identifier, autoplay: entry.autoplay, timerSeconds: entry.timerSeconds)
    let cachedImageURL = ArtworkService.getCachedImageURL(for: identifier)

    return Link(destination: url) {
      VStack(spacing: 5) {
        Image(uiImage: UIImage(contentsOfFile: cachedImageURL.path)
              ?? ArtworkService.generateDefaultArtwork(from: entry.theme?.linkColor)!)
          .resizable()
          .frame(minWidth: 60, maxWidth: 60, minHeight: 60, maxHeight: 60)
          .aspectRatio(1.0, contentMode: .fit)
          .cornerRadius(8.0)

        Text(title)
          .fontWeight(.semibold)
          .foregroundColor(titleColor)
          .font(.caption)
          .lineLimit(2)
          .frame(width: nil, height: 34, alignment: .leading)
      }
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
                    BookView(item: item, titleColor: widgetColors.primaryColor, theme: entry.theme, entry: entry)
                }
            }
            .padding([.leading, .trailing])

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(widgetColors.backgroundColor)
    }
}

struct RecentBooksWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
          RecentBooksWidgetView(entry: LibraryEntry(date: Date(), items: [], theme: nil, timerSeconds: 300, autoplay: true))
                .previewContext(WidgetPreviewContext(family: .systemMedium))
        }
    }
}

struct RecentBooksWidget: Widget {
    let kind: String = "com.bookplayer.widget.medium.recentBooks"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: PlayAndSleepActionIntent.self, provider: RecentBooksProvider()) { entry in
            RecentBooksWidgetView(entry: entry)
        }
        .configurationDisplayName("Recent Books")
        .description("See the recent played books")
        .supportedFamilies([.systemMedium])
    }
}
