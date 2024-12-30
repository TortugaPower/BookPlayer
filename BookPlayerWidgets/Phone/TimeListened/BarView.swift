//
//  BarView.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 13/12/20.
//  Copyright © 2020 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import WidgetKit
import BookPlayerKit

struct BarView: View {
  var currentTime: Double
  var date: Date
  var maxTime: Double
  var cornerRadius: CGFloat
  var widgetColors: WidgetColors

  var body: some View {
    let time = WidgetUtils.formatTimeShort(currentTime)

    let day = Calendar.current.component(.day, from: date)
    let formatter = DateFormatter()
    formatter.dateStyle = .medium

    let derp = CGFloat((currentTime * 70) / maxTime)

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
        .accessibility(hidden: true)
    }
    .background(widgetColors.backgroundColor)
    .frame(width: 40, height: 100)
    .accessibilityElement(children: .combine)
    .accessibilityValue("Hours, \(WidgetUtils.formatDate(date))")
  }
}

struct BarView_Previews: PreviewProvider {
  static var previews: some View {
    BarView(
      currentTime: 20,
      date: Date(),
      maxTime: 70,
      cornerRadius: CGFloat(integerLiteral: 7),
      widgetColors: WidgetUtils.getColors(
        from: SimpleTheme.getDefaultTheme(),
        with: .light
      )
    )
    .previewContext(WidgetPreviewContext(family: .systemMedium))
  }
}
