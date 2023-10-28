//
//  WidgetUtils.swift
//  BookPlayerWidgetUIExtension
//
//  Created by Gianni Carlo on 16/12/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import SwiftUI
import WidgetKit

struct WidgetColors {
  let primaryColor: Color
  let accentColor: Color
  let backgroundColor: Color
}

struct PlaybackRecordViewer: Hashable {
  var time: Double
  var date: Date
}

extension PlaybackRecordViewer {
  init(record: PlaybackRecord?, date: Date) {
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

  class func getPlaybackRecord(with libraryService: LibraryService) -> PlaybackRecordViewer {
    let record = libraryService.getCurrentPlaybackRecord()
    return PlaybackRecordViewer(record: record, date: Date())
  }

  class func getPlaybackRecords(with libraryService: LibraryService) -> [PlaybackRecordViewer] {
    let (
      startFirstDay,
      startSecondDay,
      startThirdDay,
      startFourthDay,
      startFifthDay,
      startSixthDay,
      startSeventhDay,
      endDate
    ) = Self.getDateRangesForListenedTime()

    let firstRecord = (libraryService.getPlaybackRecords(from: startFirstDay, to: startSecondDay) ?? []).first
    let firstRecordViewer = PlaybackRecordViewer(record: firstRecord, date: startFirstDay)
    let secondRecord = (libraryService.getPlaybackRecords(from: startSecondDay, to: startThirdDay) ?? []).first
    let secondRecordViewer = PlaybackRecordViewer(record: secondRecord, date: startSecondDay)
    let thirdRecord = (libraryService.getPlaybackRecords(from: startThirdDay, to: startFourthDay) ?? []).first
    let thirdRecordViewer = PlaybackRecordViewer(record: thirdRecord, date: startThirdDay)
    let fourthRecord = (libraryService.getPlaybackRecords(from: startFourthDay, to: startFifthDay) ?? []).first
    let fourthRecordViewer = PlaybackRecordViewer(record: fourthRecord, date: startFourthDay)
    let fifthRecord = (libraryService.getPlaybackRecords(from: startFifthDay, to: startSixthDay) ?? []).first
    let fifthRecordViewer = PlaybackRecordViewer(record: fifthRecord, date: startFifthDay)
    let sixthRecord = (libraryService.getPlaybackRecords(from: startSixthDay, to: startSeventhDay) ?? []).first
    let sixthRecordViewer = PlaybackRecordViewer(record: sixthRecord, date: startSixthDay)
    let seventhRecord = (libraryService.getPlaybackRecords(from: startSeventhDay, to: endDate) ?? []).first
    let seventhRecordViewer = PlaybackRecordViewer(record: seventhRecord, date: startSeventhDay)

    return [
      firstRecordViewer,
      secondRecordViewer,
      thirdRecordViewer,
      fourthRecordViewer,
      fifthRecordViewer,
      sixthRecordViewer,
      seventhRecordViewer
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
    return UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)?.string(forKey: Constants.UserDefaults.appIcon) ?? "Default"
  }

  class func getWidgetActionURL(with bookIdentifier: String?, autoplay: Bool, timerSeconds: Double) -> URL {
    let urlString = CommandParser.createWidgetActionString(with: bookIdentifier, autoplay: autoplay, timerSeconds: timerSeconds)
    return URL(string: urlString)!
  }

  class func getColors(from theme: SimpleTheme, with colorScheme: ColorScheme) -> WidgetColors {
    let hexPrimary: String = colorScheme == .dark
    ? theme.darkPrimaryHex
    : theme.lightPrimaryHex
    let hexAccent: String = colorScheme == .dark
    ? theme.darkAccentHex
    : theme.lightAccentHex
    let hexBackground: String = colorScheme == .dark
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

    return [firstRecordViewer, secondRecordViewer, thirdRecordViewer, fourthRecordViewer, fifthRecordViewer, sixthRecordViewer, seventhRecordViewer]
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
    if #available(iOSApplicationExtension 17.0, *) {
      return self.contentMarginsDisabled()
    } else {
      return self
    }
  }
}
