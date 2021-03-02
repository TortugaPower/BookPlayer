//
//  LastPlayedWidgetView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 24/11/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct PlayAndSleepProvider: IntentTimelineProvider {
    typealias Entry = SimpleEntry

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), title: nil, artwork: nil, theme: nil, timerSeconds: 300, autoplay: true)
    }

    func getSnapshot(for configuration: PlayAndSleepActionIntent, in context: Context, completion: @escaping (Entry) -> Void) {
        let library = DataManager.getLibrary()
        let title = library.lastPlayedBook?.currentChapter?.title
            ?? library.lastPlayedBook?.title
        let autoplay = configuration.autoplay?.boolValue ?? true
        let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

        let entry = SimpleEntry(date: Date(),
                                title: title,
                                artwork: library.lastPlayedBook?.getArtwork(for: library.currentTheme),
                                theme: library.currentTheme,
                                timerSeconds: seconds,
                                autoplay: autoplay)

        completion(entry)
    }

    func getTimeline(for configuration: PlayAndSleepActionIntent, in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let library = DataManager.getLibrary()
        let title = library.lastPlayedBook?.currentChapter?.title
            ?? library.lastPlayedBook?.title
        let autoplay = configuration.autoplay?.boolValue ?? true
        let seconds = TimeParser.getSeconds(from: configuration.sleepTimer)

        let entries: [SimpleEntry] = [SimpleEntry(date: Date(), title: title, artwork: library.lastPlayedBook?.getArtwork(for: library.currentTheme), theme: library.currentTheme, timerSeconds: seconds, autoplay: autoplay)]
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct LastPlayedWidgetView: View {
    @Environment(\.colorScheme) var colorScheme
    var entry: PlayAndSleepProvider.Entry

    var body: some View {
        let titleLabel = entry.title ?? "---"

        let widgetColors = WidgetUtils.getColors(from: entry.theme, with: colorScheme)

        let url = WidgetUtils.getWidgetActionURL(with: nil, autoplay: entry.autoplay, timerSeconds: entry.timerSeconds)

        let appIconName = WidgetUtils.getAppIconName()

        return VStack {
            HStack {
                if let artwork = entry.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .frame(width: 90, height: 90)
                        .aspectRatio(1.0, contentMode: .fit)
                        .cornerRadius(8.0)
                } else {
                    Rectangle()
                        .fill(Color.secondary)
                        .frame(width: 90, height: 90)
                        .aspectRatio(1.0, contentMode: .fit)
                        .cornerRadius(8.0)
                }

                VStack {
                    Image(appIconName)
                        .accessibility(hidden: true)
                        .frame(width: 32, height: 32)
                        .padding([.trailing], 10)
                        .cornerRadius(8.0)
                    Spacer()
                }
            }
            .frame(height: 90)
            .padding([.leading])
            .padding([.top], 8)
            .accessibility(label: Text("Last Played Book, \(titleLabel)"))
            VStack(alignment: .leading) {
                Text(titleLabel)
                    .fontWeight(.semibold)
                    .foregroundColor(widgetColors.primaryColor)
                    .font(.footnote)
                    .lineLimit(2)
                    .accessibility(hidden: true)
                Spacer()
            }
            .frame(height: 40)
            .padding([.leading, .trailing])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(widgetColors.backgroundColor)
        .widgetURL(url)
    }
}

struct LastPlayedWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LastPlayedWidgetView(entry: SimpleEntry(date: Date(), title: "Test Book Title", artwork: UIImage(named: "defaultArtwork"), theme: nil, timerSeconds: 300, autoplay: true))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            LastPlayedWidgetView(entry: SimpleEntry(date: Date(), title: nil, artwork: nil, theme: nil, timerSeconds: 300, autoplay: true))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            LastPlayedWidgetView(entry: SimpleEntry(date: Date(), title: "Test Book Title", artwork: UIImage(named: "defaultArtwork"), theme: nil, timerSeconds: 300, autoplay: true))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.colorScheme, .dark)
            LastPlayedWidgetView(entry: SimpleEntry(date: Date(), title: nil, artwork: nil, theme: nil, timerSeconds: 300, autoplay: true))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.colorScheme, .dark)
        }
    }
}

struct LastPlayedWidget: Widget {
    let kind: String = "com.bookplayer.widget.small.lastPlayed"

    var body: some WidgetConfiguration {
        IntentConfiguration(kind: kind, intent: PlayAndSleepActionIntent.self, provider: PlayAndSleepProvider()) { entry in
            LastPlayedWidgetView(entry: entry)
        }
        .configurationDisplayName("Last Played Book")
        .description("See and play your last played book")
        .supportedFamilies([.systemSmall])
    }
}
