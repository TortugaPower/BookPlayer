//
//  BarView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 13/12/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import SwiftUI

struct BarView: View {
    var playbackRecordViewer: PlaybackRecordViewer
    var maxTime: Double
    var cornerRadius: CGFloat
    var widgetColors: WidgetColors

    var body: some View {
        let time = WidgetUtils.formatTimeShort(playbackRecordViewer.time)

        let day = Calendar.current.component(.day, from: playbackRecordViewer.date)

        let derp = CGFloat((playbackRecordViewer.time * 70) / maxTime)

        return VStack(spacing: 4) {
            Text(time)
                .foregroundColor(widgetColors.primaryColor)
                .font(.caption2)
            VStack {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .frame(width: 20, height: 70).foregroundColor(widgetColors.backgroundColor)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .frame(width: 20, height: derp).foregroundColor(widgetColors.accentColor)
                }
            }
            Text("\(day)")
                .foregroundColor(widgetColors.primaryColor)
                .font(.caption)
                .padding(.bottom, 8)
        }
        .background(widgetColors.backgroundColor)
        .frame(width: 40, height: 100)
    }
}
