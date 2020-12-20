//
//  TimeListenedMediumView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 13/12/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct TimeListenedMediumView: View {
    @Environment(\.colorScheme) var colorScheme
    var entry: TimeListenedProvider.Entry

    var body: some View {
        let titleLabel = entry.library?.lastPlayedBook?.title ?? "---"

        let widgetColors = WidgetUtils.getColors(from: entry.library?.currentTheme, with: colorScheme)

        let appIconName = WidgetUtils.getAppIconName()

        let url = WidgetUtils.getWidgetActionURL(with: nil, autoplay: entry.autoplay, timerSeconds: entry.timerSeconds)

        let maxTime = entry.playbackRecords.max { (record1, record2) -> Bool in
            record1.time < record2.time
        }?.time ?? 0

        let totalTime = entry.playbackRecords.reduce(0) { $0 + $1.time }
        let formattedTotalTime = WidgetUtils.formatTime(totalTime)

        return VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Listened Time (Hours / Day)")
                    .foregroundColor(widgetColors.primaryColor)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .accessibility(label: Text("Listened Time per Day."))
                Spacer()
                Image(appIconName)
                    .accessibility(hidden: true)
                    .frame(width: 28, height: 28)
                    .padding([.trailing], 10)
                    .cornerRadius(8.0)
            }
            .padding([.leading])
            .padding([.trailing], 5)
            .padding([.top], 7)

            Spacer()

            HStack(alignment: .center, spacing: 11) {
                Group {
                    ForEach(entry.playbackRecords, id: \.self) { record in
                        BarView(currentTime: record.time, date: record.date, maxTime: maxTime, cornerRadius: CGFloat(integerLiteral: 7), widgetColors: widgetColors)
                    }
                }
                .frame(width: 20)
                VStack {
                    Text("Total")
                        .fontWeight(.semibold)
                        .foregroundColor(widgetColors.primaryColor)
                        .accessibility(label: Text("Total Listened Time in the last 7 days."))
                    Text("\(formattedTotalTime)")
                        .foregroundColor(widgetColors.primaryColor)
                        .font(.footnote)
                        .padding([.bottom], 1)

                    VStack {
                        Text("Last Book")
                            .fontWeight(.semibold)
                            .foregroundColor(widgetColors.primaryColor)
                        Text("\(titleLabel)")
                            .foregroundColor(widgetColors.primaryColor)
                            .font(.footnote)
                            .lineLimit(2)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                }
                .padding([.leading, .trailing], 5)
            }.animation(.default)
                .padding([.leading])
                .padding([.trailing], 5)
                .padding([.bottom], 5)
        }
        .background(widgetColors.backgroundColor)
        .widgetURL(url)
    }
}

struct TimeListenedMediumView_Previews: PreviewProvider {
    static var previews: some View {
        TimeListenedMediumView(entry: TimeListenedEntry(date: Date(), library: nil, timerSeconds: 300, autoplay: true, playbackRecords: WidgetUtils.getTestDataPlaybackRecords(.systemMedium)))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
