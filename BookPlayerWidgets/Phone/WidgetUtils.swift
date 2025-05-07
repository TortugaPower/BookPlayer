//
//  WidgetUtils.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 16/12/20.
//  Copyright © 2020 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftUI
import WidgetKit

#if os(watchOS)
  import BookPlayerWatchKit
#else
  import BookPlayerKit
  import UIKit
#endif

struct WidgetColors {
  let primaryColor: Color
  let accentColor: Color
  let backgroundColor: Color
}

struct PlaybackRecordViewer: Hashable, Codable {
  var time: Double
  var date: Date
}

extension PlaybackRecordViewer {
  init(record: SimplePlaybackRecord?, date: Date) {
    self.date = date
    self.time = 0

    if let record = record {
      self.time = record.time
    }
  }
}

class WidgetUtils {
  // swiftlint:disable:next large_tuple
  typealias ListenedDateRanges = (
    firstDate: Date,
    secondDate: Date,
    thirdDate: Date,
    fourthDate: Date,
    fifthDate: Date,
    sixthDate: Date,
    seventhDate: Date,
    endDate: Date
  )

  class func getDateRangesForListenedTime() -> ListenedDateRanges {
    let calendar = Calendar.current
    let now = Date()
    let startToday = calendar.startOfDay(for: now)
    let endDate = calendar.date(byAdding: .day, value: 1, to: startToday)!

    let startFirstDay = calendar.date(byAdding: .day, value: -7, to: endDate)!
    let startSecondDay = calendar.date(byAdding: .day, value: 1, to: startFirstDay)!
    let startThirdDay = calendar.date(byAdding: .day, value: 1, to: startSecondDay)!
    let startFourthDay = calendar.date(byAdding: .day, value: 1, to: startThirdDay)!
    let startFifthDay = calendar.date(byAdding: .day, value: 1, to: startFourthDay)!
    let startSixthDay = calendar.date(byAdding: .day, value: 1, to: startFifthDay)!
    let startSeventhDay = calendar.date(byAdding: .day, value: 1, to: startSixthDay)!

    return (
      startFirstDay,
      startSecondDay,
      startThirdDay,
      startFourthDay,
      startFifthDay,
      startSixthDay,
      startSeventhDay,
      endDate
    )
  }

  class func getLastPlaybackRecord() -> PlaybackRecordViewer {
    let record = Self.getRecordsFromDefaults().first
    return PlaybackRecordViewer(record: record, date: Date())
  }

  class func getRecordsFromDefaults() -> [SimplePlaybackRecord] {
    guard
      let recordsData = UserDefaults.sharedDefaults.data(forKey: Constants.UserDefaults.sharedWidgetPlaybackRecords),
      let records = try? JSONDecoder().decode([SimplePlaybackRecord].self, from: recordsData)
    else {
      return []
    }

    return records
  }

  class func getPlaybackRecords() -> [PlaybackRecordViewer] {
    let (
      startFirstDay,
      startSecondDay,
      startThirdDay,
      startFourthDay,
      startFifthDay,
      startSixthDay,
      startSeventhDay,
      _
    ) = Self.getDateRangesForListenedTime()

    let records = Self.getRecordsFromDefaults()

    let firstRecord = records.first(where: { $0.date >= startFirstDay && $0.date < startSecondDay })
    let firstRecordViewer = PlaybackRecordViewer(record: firstRecord, date: startFirstDay)
    let secondRecord = records.first(where: { $0.date >= startSecondDay && $0.date < startThirdDay })
    let secondRecordViewer = PlaybackRecordViewer(record: secondRecord, date: startSecondDay)
    let thirdRecord = records.first(where: { $0.date >= startThirdDay && $0.date < startFourthDay })
    let thirdRecordViewer = PlaybackRecordViewer(record: thirdRecord, date: startThirdDay)
    let fourthRecord = records.first(where: { $0.date >= startFourthDay && $0.date < startFifthDay })
    let fourthRecordViewer = PlaybackRecordViewer(record: fourthRecord, date: startFourthDay)
    let fifthRecord = records.first(where: { $0.date >= startFifthDay && $0.date < startSixthDay })
    let fifthRecordViewer = PlaybackRecordViewer(record: fifthRecord, date: startFifthDay)
    let sixthRecord = records.first(where: { $0.date >= startSixthDay && $0.date < startSeventhDay })
    let sixthRecordViewer = PlaybackRecordViewer(record: sixthRecord, date: startSixthDay)
    let seventhRecord = records.first(where: { $0.date >= startSeventhDay })
    let seventhRecordViewer = PlaybackRecordViewer(record: seventhRecord, date: startSeventhDay)

    return [
      firstRecordViewer,
      secondRecordViewer,
      thirdRecordViewer,
      fourthRecordViewer,
      fifthRecordViewer,
      sixthRecordViewer,
      seventhRecordViewer,
    ]
  }

  class func getNextDayDate() -> Date {
    let calendar = Calendar.current
    let now = Date()
    let startToday = calendar.startOfDay(for: now)
    return calendar.date(byAdding: .day, value: 1, to: startToday)!
  }

  class func formatTime(_ time: Double) -> String {
    let hours = Int(time / 3600)
    let minutes = Int(time.truncatingRemainder(dividingBy: 3600) / 60)

    return "\(hours)H \(minutes)M"
  }

  class func formatTimeShort(_ time: Double) -> String {
    let hours = time / 3600

    return String(format: "%.2f", hours)
  }

  class func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.timeStyle = .none
    formatter.dateStyle = .medium
    formatter.doesRelativeDateFormatting = true
    return formatter.string(from: date)
  }

  class func getAppIconName() -> String {
    return UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)?.string(forKey: Constants.UserDefaults.appIcon)
      ?? "Default"
  }

  class func getWidgetActionURL(with bookIdentifier: String?, autoplay: Bool, timerSeconds: Double?) -> URL {
    let urlString = CommandParser.createWidgetActionString(
      with: bookIdentifier,
      autoplay: autoplay,
      timerSeconds: timerSeconds
    )
    return URL(string: urlString)!
  }

  class func getWidgetActionURL(
    with bookIdentifier: String?,
    playbackToggle: Bool
  ) -> URL {
    let urlString = CommandParser.createWidgetActionString(
      with: bookIdentifier,
      playbackToggle: playbackToggle
    )
    return URL(string: urlString)!
  }

  class func getColors(from theme: SimpleTheme, with colorScheme: ColorScheme) -> WidgetColors {
    let hexPrimary: String =
      colorScheme == .dark
      ? theme.darkPrimaryHex
      : theme.lightPrimaryHex
    let hexAccent: String =
      colorScheme == .dark
      ? theme.darkAccentHex
      : theme.lightAccentHex
    let hexBackground: String =
      colorScheme == .dark
      ? theme.darkSystemBackgroundHex
      : theme.lightSystemBackgroundHex

    let primaryColor = UIColor(hex: hexPrimary)
    let accentColor = UIColor(hex: hexAccent)
    let backgroundColor = UIColor(hex: hexBackground)

    return WidgetColors(
      primaryColor: Color(primaryColor),
      accentColor: Color(accentColor),
      backgroundColor: Color(backgroundColor)
    )
  }
}

extension View {
  public func widgetBackground(backgroundView: some View) -> some View {
    if #available(watchOS 10.0, iOSApplicationExtension 17.0, iOS 17.0, macOSApplicationExtension 14.0, *) {
      return containerBackground(for: .widget) {
        backgroundView
      }
    } else {
      return background(backgroundView)
    }
  }
}

extension WidgetConfiguration {
  public func contentMarginsDisabledIfAvailable() -> some WidgetConfiguration {
    if #available(iOSApplicationExtension 17.0, iOS 15.0, *) {
      return self.contentMarginsDisabled()
    } else {
      return self
    }
  }
}

#if os(iOS)
  extension WidgetUtils {
    class func isValidSize(image: UIImage) -> Bool {
      let maxArea: CGFloat = 718_080.0

      let originalWidth = image.size.width
      let originalHeight = image.size.height
      let originalArea = originalWidth * originalHeight

      return originalArea <= maxArea
    }

    class func getArtworkImage(for relativePath: String, theme: SimpleTheme) -> UIImage? {
      let path = ArtworkService.getCachedImageURL(for: relativePath).path

      guard
        let image = UIImage(contentsOfFile: path)
          ?? ArtworkService.generateDefaultArtwork(from: theme.linkColor)
      else {
        return nil
      }

      return Self.resizedForWidget(image)
    }

    /// Base logic taken from: https://stackoverflow.com/q/79409995
    /// Resize the image to strictly fit within WidgetKit’s max allowed pixel area (718,080 pixels)
    class func resizedForWidget(_ image: UIImage) -> UIImage? {
      if Self.isValidSize(image: image) {
        return image
      }

      let maxArea: CGFloat = 718_080.0
      let originalWidth = image.size.width
      let originalHeight = image.size.height
      let originalArea = originalWidth * originalHeight

      /// Calculate the exact scale factor to fit within maxArea
      let scaleFactor = sqrt(maxArea / originalArea)
      /// Use `floor` to ensure area is always within limits
      let newWidth = floor(originalWidth * scaleFactor)
      let newHeight = floor(originalHeight * scaleFactor)
      let newSize = CGSize(width: newWidth, height: newHeight)

      /// Force bitmap rendering to ensure the resized image is properly stored
      let format = UIGraphicsImageRendererFormat()
      format.opaque = true
      /// Ensures we are not letting UIKit auto-scale it back up
      format.scale = 1

      let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
      let resizedImage = renderer.image { _ in
        image.draw(in: CGRect(origin: .zero, size: newSize))
      }

      return resizedImage
    }

    class func getTestDataPlaybackRecords(_ family: WidgetFamily) -> [PlaybackRecordViewer] {
      guard family == .systemMedium else {
        return [PlaybackRecordViewer(time: 20, date: Date())]
      }

      let calendar = Calendar.current
      let now = Date()
      let startToday = calendar.startOfDay(for: now)
      let endDate = calendar.date(byAdding: .day, value: 1, to: startToday)!

      let startFirstDay = calendar.date(byAdding: .day, value: -8, to: endDate)!
      let startSecondDay = calendar.date(byAdding: .day, value: 1, to: startFirstDay)!
      let startThirdDay = calendar.date(byAdding: .day, value: 1, to: startSecondDay)!
      let startFourthDay = calendar.date(byAdding: .day, value: 1, to: startThirdDay)!
      let startFifthDay = calendar.date(byAdding: .day, value: 1, to: startFourthDay)!
      let startSixthDay = calendar.date(byAdding: .day, value: 1, to: startFifthDay)!
      let startSeventhDay = calendar.date(byAdding: .day, value: 1, to: startSixthDay)!

      let firstRecordViewer = PlaybackRecordViewer(time: 20, date: startFirstDay)
      let secondRecordViewer = PlaybackRecordViewer(time: 60, date: startSecondDay)
      let thirdRecordViewer = PlaybackRecordViewer(time: 0, date: startThirdDay)
      let fourthRecordViewer = PlaybackRecordViewer(time: 20, date: startFourthDay)
      let fifthRecordViewer = PlaybackRecordViewer(time: 120, date: startFifthDay)
      let sixthRecordViewer = PlaybackRecordViewer(time: 3600, date: startSixthDay)
      let seventhRecordViewer = PlaybackRecordViewer(time: 80, date: startSeventhDay)

      return [
        firstRecordViewer, secondRecordViewer, thirdRecordViewer, fourthRecordViewer, fifthRecordViewer,
        sixthRecordViewer, seventhRecordViewer,
      ]
    }
  }
#endif
