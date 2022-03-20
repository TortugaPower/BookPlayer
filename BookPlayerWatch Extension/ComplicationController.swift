//
//  ComplicationController.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import ClockKit
import SwiftUI
import BookPlayerWatchKit

class ComplicationController: NSObject, CLKComplicationDataSource {

  // MARK: - Complication Configuration

  func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
    let descriptors = [
      CLKComplicationDescriptor(
        identifier: "complication",
        displayName: "BookPlayer",
        supportedFamilies: [
          .circularSmall,
          .modularSmall,
          .modularLarge,
          .utilitarianSmall,
          .utilitarianSmallFlat,
          .utilitarianLarge,
          .graphicCorner,
          .graphicCircular,
          .graphicRectangular
        ]
      )
    ]

    handler(descriptors)
  }

  func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
    // Do any necessary work to support these newly shared complication descriptors
  }

  // MARK: - Timeline Configuration

  func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
    // Call the handler with the last entry date you can currently provide or nil if you can't support future timelines
    handler(nil)
  }

  func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
    // Call the handler with your desired behavior when the device is locked
    handler(.showOnLockScreen)
  }

  // MARK: - Timeline Population

  func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
    // Call the handler with the current timeline entry
    let testChapter = PlayableChapter(
      title: "test chapter",
      author: "test author",
      start: 0,
      duration: 50,
      relativePath: "",
      index: 1
    )
    let item = PlayableItem(title: "The Last Shadow: Other Tales from the Ender Universe", author: "Orson Scott Card", chapters: [testChapter], currentTime: 0, duration: 0, relativePath: "", percentCompleted: 0.7, isFinished: false, useChapterTimeContext: false)
    if let ctemplate = makeTemplate(for: item, complication: complication) {
      let entry = CLKComplicationTimelineEntry(
        date: Date(),
        complicationTemplate: ctemplate)
      handler(entry)
    } else {
      handler(nil)
    }
  }

  func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
    // Call the handler with the timeline entries after the given date
    handler(nil)
  }

  // MARK: - Sample Templates

  func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
    if let template = makeTemplate(for: nil, complication: complication) {
      handler(template)
    } else {
      handler(nil)
    }
  }
}

extension ComplicationController {
  func makeTemplate(
    for item: PlayableItem?,
    complication: CLKComplication
  ) -> CLKComplicationTemplate? {
    switch complication.family {
    case .graphicCorner:
      let textProvider: CLKTextProvider
      let gaugeProvider: CLKSimpleGaugeProvider

      if let item = item {
        textProvider = CLKTextProvider(format: "CHP \(item.currentChapter.index)")
        gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .appTintColor, fillFraction: Float(item.percentCompleted))
      } else {
        textProvider = CLKTextProvider(format: "CHP #")
        gaugeProvider = CLKSimpleGaugeProvider(style: .fill, gaugeColor: .appTintColor, fillFraction: 0.5)
      }

      return CLKComplicationTemplateGraphicCornerGaugeText(
        gaugeProvider: gaugeProvider,
        outerTextProvider: textProvider
      )
    case .graphicRectangular:
      let headerTextProvider: CLKTextProvider
      let body1TextProvider: CLKTextProvider

      if let item = item {
        headerTextProvider = CLKTextProvider(format: "\(item.currentChapter.title)")
        body1TextProvider = CLKTextProvider(format: "\(item.title)")
      } else {
        headerTextProvider = CLKTextProvider(format: "Chapter")
        body1TextProvider = CLKTextProvider(format: "Book title")
      }

      return CLKComplicationTemplateGraphicRectangularStandardBody(
        headerTextProvider: headerTextProvider,
        body1TextProvider: body1TextProvider
      )
    case .modularLarge:
      let headerTextProvider: CLKTextProvider
      let body1TextProvider: CLKTextProvider

      if let item = item {
        headerTextProvider = CLKTextProvider(format: "\(item.currentChapter.title)")
        body1TextProvider = CLKTextProvider(format: "\(item.title)")
      } else {
        headerTextProvider = CLKTextProvider(format: "Chapter")
        body1TextProvider = CLKTextProvider(format: "Book title")
      }

      return CLKComplicationTemplateModularLargeStandardBody(
        headerTextProvider: headerTextProvider,
        body1TextProvider: body1TextProvider
      )
    default:
      return nil
    }
  }
}
