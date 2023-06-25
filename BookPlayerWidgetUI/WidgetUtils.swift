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
    init(time: Double?, date: Date) {
        self.date = date
        self.time = time ?? 0
    }
}

class WidgetUtils {
  class func getPlaybackRecord(with libraryService: LibraryService) async -> PlaybackRecordViewer {
    let recordTime = await libraryService.getCurrentPlaybackRecordTime()
    return PlaybackRecordViewer(time: recordTime, date: Date())
  }

  class func getPlaybackRecords(with libraryService: LibraryService) async -> [PlaybackRecordViewer] {
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

      let firstRecordTime = await libraryService.getFirstPlaybackRecordTime(from: startFirstDay, to: startSecondDay)
      let firstRecordViewer = PlaybackRecordViewer(time: firstRecordTime, date: startFirstDay)
      let secondRecordTime = await  libraryService.getFirstPlaybackRecordTime(from: startSecondDay, to: startThirdDay)
      let secondRecordViewer = PlaybackRecordViewer(time: secondRecordTime, date: startSecondDay)
      let thirdRecordTime = await libraryService.getFirstPlaybackRecordTime(from: startThirdDay, to: startFourthDay)
      let thirdRecordViewer = PlaybackRecordViewer(time: thirdRecordTime, date: startThirdDay)
      let fourthRecordTime = await libraryService.getFirstPlaybackRecordTime(from: startFourthDay, to: startFifthDay)
      let fourthRecordViewer = PlaybackRecordViewer(time: fourthRecordTime, date: startFourthDay)
      let fifthRecordTime = await libraryService.getFirstPlaybackRecordTime(from: startFifthDay, to: startSixthDay)
      let fifthRecordViewer = PlaybackRecordViewer(time: fifthRecordTime, date: startFifthDay)
      let sixthRecordTime = await libraryService.getFirstPlaybackRecordTime(from: startSixthDay, to: startSeventhDay)
      let sixthRecordViewer = PlaybackRecordViewer(time: sixthRecordTime, date: startSixthDay)
      let seventhRecordTime = await libraryService.getFirstPlaybackRecordTime(from: startSeventhDay, to: endDate)
      let seventhRecordViewer = PlaybackRecordViewer(time: seventhRecordTime, date: startSeventhDay)

      return [firstRecordViewer, secondRecordViewer, thirdRecordViewer, fourthRecordViewer, fifthRecordViewer, sixthRecordViewer, seventhRecordViewer]
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
        return UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)?.string(forKey: Constants.UserDefaults.appIcon.rawValue) ?? "Default"
    }

    class func getWidgetActionURL(with bookIdentifier: String?, autoplay: Bool, timerSeconds: Double) -> URL {
        let urlString = CommandParser.createWidgetActionString(with: bookIdentifier, autoplay: autoplay, timerSeconds: timerSeconds)
        return URL(string: urlString)!
    }

    class func getColors(from theme: SimpleTheme?, with colorScheme: ColorScheme) -> WidgetColors {
        var primaryColor = UIColor.label
        var accentColor = UIColor.appTintColor
        var backgroundColor = UIColor.systemBackground

        if let theme = theme {
            let hexPrimary: String = colorScheme == .dark
                ? theme.darkPrimaryHex
                : theme.lightPrimaryHex
            let hexAccent: String = colorScheme == .dark
                ? theme.darkAccentHex
                : theme.lightAccentHex
            let hexBackground: String = colorScheme == .dark
                ? theme.darkSystemBackgroundHex
                : theme.lightSystemBackgroundHex

            primaryColor = UIColor(hex: hexPrimary)
            accentColor = UIColor(hex: hexAccent)
            backgroundColor = UIColor(hex: hexBackground)
        }

        return WidgetColors(primaryColor: Color(primaryColor), accentColor: Color(accentColor), backgroundColor: Color(backgroundColor))
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
