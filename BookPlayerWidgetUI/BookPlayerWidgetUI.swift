//
//  BookPlayerWidgetUI.swift
//  BookPlayerWidgetUI
//
//  Created by Gianni Carlo on 21/11/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), title: nil, artwork: nil, theme: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> Void) {
        let library = DataManager.getLibrary()
        let title = library.lastPlayedBook?.currentChapter?.title
            ?? library.lastPlayedBook?.title
        let entry = SimpleEntry(date: Date(),
                                title: title,
                                artwork: library.lastPlayedBook?.artwork,
                                theme: library.currentTheme)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let library = DataManager.getLibrary()
        let title = library.lastPlayedBook?.currentChapter?.title
            ?? library.lastPlayedBook?.title

        let entries: [SimpleEntry] = [SimpleEntry(date: Date(), title: title, artwork: library.lastPlayedBook?.artwork, theme: library.currentTheme)]
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let title: String?
    let artwork: UIImage?
    let theme: Theme?
}

struct BookPlayerWidgetUIEntryView: View {
    @Environment(\.colorScheme) var colorScheme
    var entry: Provider.Entry

    var body: some View {
        let titleLabel = entry.title ?? "---"

        var titleColor = UIColor.label
        var backgroundColor = UIColor.systemBackground

        if let theme = entry.theme {
            let hexPrimary: String = colorScheme == .dark
                ? theme.darkAccentHex
                : theme.defaultAccentHex
            let hexBackground: String = colorScheme == .dark
                ? theme.darkBackgroundHex
                : theme.defaultBackgroundHex

            titleColor = UIColor(hex: hexPrimary)
            backgroundColor = UIColor(hex: hexBackground)
        }

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
                    Image("WidgetAppIconDark")
                        .frame(width: 32, height: 32)
                        .padding([.trailing], 10)
                        .cornerRadius(8.0)
                    Spacer()
                }
            }
            .frame(height: 90)
            .padding([.leading])
            .padding([.top], 8)
            VStack(alignment: .leading) {
                Text(titleLabel)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(titleColor))
                    .font(.footnote)
                    .lineLimit(2)
                Spacer()
            }
            .frame(height: 40)
            .padding([.leading, .trailing])
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(backgroundColor))
    }
}

@main
struct BookPlayerWidgetUI: Widget {
    let kind: String = "BookPlayerWidgetUI"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BookPlayerWidgetUIEntryView(entry: entry)
        }
        .configurationDisplayName("BookPlayer")
        .description("Last Played book")
        .supportedFamilies([.systemSmall])
    }
}

struct BookPlayerWidgetUI_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BookPlayerWidgetUIEntryView(entry: SimpleEntry(date: Date(), title: "Test Book Title", artwork: UIImage(named: "defaultArtwork"), theme: nil))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            BookPlayerWidgetUIEntryView(entry: SimpleEntry(date: Date(), title: nil, artwork: nil, theme: nil))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
            BookPlayerWidgetUIEntryView(entry: SimpleEntry(date: Date(), title: "Test Book Title", artwork: UIImage(named: "defaultArtwork"), theme: nil))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.colorScheme, .dark)
            BookPlayerWidgetUIEntryView(entry: SimpleEntry(date: Date(), title: nil, artwork: nil, theme: nil))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .environment(\.colorScheme, .dark)
        }
    }
}
