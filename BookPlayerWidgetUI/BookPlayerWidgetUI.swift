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

struct SimpleEntry: TimelineEntry {
    let date: Date
    let title: String?
    let artwork: UIImage?
    let theme: Theme?
    let timerSeconds: Double
    let autoplay: Bool
}

struct LibraryEntry: TimelineEntry {
    let date: Date
    let library: Library?
    let timerSeconds: Double
    let autoplay: Bool
}

struct TimeListenedEntry: TimelineEntry {
    let date: Date
    let library: Library?
    let timerSeconds: Double
    let autoplay: Bool
    let playbackRecords: [PlaybackRecordViewer]
}

struct BookPlayerWidgetUI_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LastPlayedWidgetView(entry: SimpleEntry(date: Date(), title: "Test Book Title", artwork: UIImage(named: "defaultArtwork"), theme: nil, timerSeconds: 300, autoplay: true))
                .previewContext(WidgetPreviewContext(family: .systemSmall))
        }
    }
}

@main
struct BookPlayerBundle: WidgetBundle {
    @WidgetBundleBuilder
    var body: some Widget {
        LastPlayedWidget()
        RecentBooksWidget()
        TimeListenedWidget()
    }
}
