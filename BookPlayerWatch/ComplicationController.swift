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

  @available(watchOS 9.0, *)
  var widgetMigrator: CLKComplicationWidgetMigrator { self }

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

  // MARK: - Timeline Configuration

  func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
    // Call the handler with your desired behavior when the device is locked
    handler(.showOnLockScreen)
  }

  // MARK: - Timeline Population

  func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
    guard let item = ExtensionDelegate.contextManager.applicationContext.currentItem else {
      handler(nil)
      return
    }

    if let template = makeTemplate(for: item, complication: complication) {
      let entry = CLKComplicationTimelineEntry(
        date: Date(),
        complicationTemplate: template)
      handler(entry)
    } else {
      handler(nil)
    }
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
      var text = "CHP #"
      var fillFraction: Float = 0.5

      if let item = item {
        text = "CHP \(item.currentChapter.index)"
        fillFraction = Float(item.percentCompleted / 100)
      }

      return CLKComplicationTemplateGraphicCornerGaugeText(
        gaugeProvider: CLKSimpleGaugeProvider(
          style: .fill,
          gaugeColor: .appTintColor,
          fillFraction: fillFraction
        ),
        outerTextProvider: CLKTextProvider(format: text)
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

@available(watchOS 9.0, *)
extension ComplicationController: CLKComplicationWidgetMigrator {

  func getWidgetConfiguration(
    from complicationDescriptor: CLKComplicationDescriptor,
    completionHandler: @escaping (CLKComplicationWidgetMigrationConfiguration?) -> Void
  ) {
    let bundleIdentifier = Bundle.main.configurationString(for: .bundleIdentifier)

    completionHandler(CLKComplicationStaticWidgetMigrationConfiguration(
      kind: "com.bookplayer.shared.widget",
      extensionBundleIdentifier: "\(bundleIdentifier).watchkitapp.widgets"
    ))
  }
}
