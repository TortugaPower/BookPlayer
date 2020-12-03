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
    typealias Entry = LibraryEntry

    func placeholder(in context: Context) -> LibraryEntry {
        LibraryEntry(date: Date(), library: nil, timerSeconds: 300, autoplay: true)
    }

    func getSnapshot(for configuration: PlayAndSleepActionIntent, in context: Context, completion: @escaping (LibraryEntry) -> Void) {
        let library = DataManager.getLibrary()
        let autoplay = configuration.autoplay?.boolValue ?? true
        let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

        let entry = LibraryEntry(date: Date(),
                                 library: library,
                                 timerSeconds: seconds,
                                 autoplay: autoplay)

        completion(entry)
    }

    func getTimeline(for configuration: PlayAndSleepActionIntent, in context: Context, completion: @escaping (Timeline<LibraryEntry>) -> Void) {
        let library = DataManager.getLibrary()
        let autoplay = configuration.autoplay?.boolValue ?? true
        let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

        let entries: [LibraryEntry] = [LibraryEntry(date: Date(), library: library, timerSeconds: seconds, autoplay: autoplay)]
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct BookView: View {
    var item: BookPlayerKit.LibraryItem
    var titleColor: UIColor
    var entry: RecentBooksProvider.Entry

    var body: some View {
        let title = item.title ?? "---"

        var identifier: String?

        if let book = item as? Book {
            identifier = book.identifier!
        } else if let playlist = item as? Playlist,
            let book = playlist.getBookToPlay() ?? playlist.getBook(at: 0) {
            identifier = book.identifier!
        }

        let urlString = CommandParser.createWidgetActionString(with: identifier, autoplay: entry.autoplay, timerSeconds: entry.timerSeconds)
        let url = URL(string: urlString)!

        return Link(destination: url) {
            VStack(spacing: 5) {
                if let artwork = item.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .frame(minWidth: 60, maxWidth: 60, minHeight: 60, maxHeight: 60)
                        .aspectRatio(1.0, contentMode: .fit)
                        .cornerRadius(8.0)
                } else {
                    Rectangle()
                        .fill(Color.secondary)
                        .aspectRatio(1.0, contentMode: .fit)
                        .cornerRadius(8.0)
                }
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(titleColor))
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
        let items = Array(entry.library?.getItemsOrderedByDate().prefix(4) ?? [])

        var primaryColor = UIColor.label
        var backgroundColor = UIColor.systemBackground

        if let theme = entry.library?.currentTheme {
            let hexPrimary: String = colorScheme == .dark
                ? theme.darkPrimaryHex
                : theme.defaultPrimaryHex
            let hexBackground: String = colorScheme == .dark
                ? theme.darkBackgroundHex
                : theme.defaultBackgroundHex

            primaryColor = UIColor(hex: hexPrimary)
            backgroundColor = UIColor(hex: hexBackground)
        }
        return VStack(spacing: 3) {
            HStack {
                Text("Recent Books")
                    .foregroundColor(Color(primaryColor))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Image("WidgetAppIconDark")
                    .frame(width: 28, height: 28)
                    .padding([.trailing], 10)
                    .cornerRadius(8.0)
            }
            .padding([.leading])
            .padding([.trailing, .bottom], 5)
            .padding([.top], 8)
            HStack {
                ForEach(items, id: \.identifier) { item in
                    BookView(item: item, titleColor: primaryColor, entry: entry)
                }
            }
            .padding([.leading, .trailing])

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(backgroundColor))
    }
}

struct RecentBooksWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RecentBooksWidgetView(entry: LibraryEntry(date: Date(), library: nil, timerSeconds: 300, autoplay: true))
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
