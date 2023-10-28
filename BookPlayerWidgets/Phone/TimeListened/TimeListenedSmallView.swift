//
//  TimeListenedSmallView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 13/12/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct TimeListenedSmallView: View {
  @Environment(\.colorScheme) var colorScheme
  var entry: TimeListenedProvider.Entry

  var body: some View {
    let widgetColors = WidgetUtils.getColors(from: entry.theme, with: colorScheme)

    var dateLabel = "Today"
    var time = "--:--"

    let titleLabel = entry.title ?? "---"

    if let playbackRecord = entry.playbackRecords.first {
      time = WidgetUtils.formatTime(playbackRecord.time)
      dateLabel = WidgetUtils.formatDate(playbackRecord.date)
    }

    let appIconName = WidgetUtils.getAppIconName()

    let url = WidgetUtils.getWidgetActionURL(with: nil, autoplay: entry.autoplay, timerSeconds: entry.timerSeconds)

    return VStack(spacing: 0) {
      HStack {
        Text("Listened")
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
      .accessibilityValue("\(dateLabel)")
      .padding([.leading])
      .padding([.trailing], 5)
      Text(time)
      Text(dateLabel)
        .font(.caption)
        .padding([.leading, .trailing])
        .padding([.bottom], 8)
        .accessibility(hidden: true)

      VStack {
        HStack {
          Text("Last Book")
            .foregroundColor(widgetColors.primaryColor)
            .font(.subheadline)
            .fontWeight(.semibold)
          Spacer()
        }
        .padding([.leading, .trailing])

        VStack(alignment: .leading) {
          Text(titleLabel)
            .font(.caption)
            .lineLimit(2)
        }
        .frame(height: 40)
        .padding([.leading, .trailing])
      }
      .accessibilityElement(children: .combine)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetBackground(backgroundView: widgetColors.backgroundColor)
    .widgetURL(url)
  }
}

struct TimeListenedSmallView_Previews: PreviewProvider {
  static var previews: some View {
    TimeListenedSmallView(entry: TimeListenedEntry(
      date: Date(),
      title: nil,
      timerSeconds: 300,
      autoplay: true,
      playbackRecords: WidgetUtils.getTestDataPlaybackRecords(.systemSmall)
    ))
    .previewContext(WidgetPreviewContext(family: .systemSmall))
  }
}
