//
//  CommandParser.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Foundation
import Intents

public enum CommandParser {
  public static func parse(_ activity: NSUserActivity) -> Action? {
    if let intent = activity.interaction?.intent {
      return self.parse(intent)
    } else if activity.activityType == "\(Bundle.main.bundleIdentifier!).activity.playback" {
      return Action(command: .play)
    }

    return nil
  }

  public static func parse(_ intent: INIntent) -> Action? {
    if let sleepIntent = intent as? SleepTimerIntent {
      var queryItem: URLQueryItem

      if let seconds = sleepIntent.seconds {
        queryItem = URLQueryItem(name: "seconds", value: seconds.stringValue)
      } else {
        let seconds = TimeInterval(sleepIntent.option)
        queryItem = URLQueryItem(name: "seconds", value: String(seconds))
      }

      return Action(command: .sleep, parameters: [queryItem])
    }

    if intent is INPlayMediaIntent {
      return Action(command: .play)
    }

    return nil
  }

  public static func parse(_ url: URL) -> Action? {
    if url.isFileURL {
      guard !DataManager.isURLInProcessedFolder(url) else {
        return nil
      }

      return Action(command: .fileImport, parameters: [URLQueryItem(name: "url", value: url.path)])
    }

    guard let host = url.host else {
      return nil
    }

    guard let command = Command(rawValue: host) else { return nil }

    if command == .download {
      guard let query = url.query, let parameter = query.components(separatedBy: "url=").last else { return nil }

      let paramURLstring = parameter.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "%22", with: "")

      let queryItem = URLQueryItem(name: "url", value: paramURLstring)

      return Action(command: command, parameters: [queryItem])
    }

    var parameters = [URLQueryItem]()

    if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
       let queryItems = components.queryItems {
      parameters = queryItems
    }

    return Action(command: command, parameters: parameters)
  }

  public static func parse(_ message: [String: Any]) -> Action? {
    guard let commandString = message["command"] as? String,
          let command = Command(rawValue: commandString) else { return nil }

    var dictionary = message
    dictionary.removeValue(forKey: "command")

    var parameters = [URLQueryItem]()

    for (key, value) in dictionary {
      guard let stringValue = value as? String else { continue }

      let queryItem = URLQueryItem(name: key, value: stringValue)
      parameters.append(queryItem)
    }

    return Action(command: command, parameters: parameters)
  }

  public static func createWidgetActionString(with bookIdentifier: String?, autoplay: Bool, timerSeconds: Double) -> String {
    var actionString = "bookplayer://widget?autoplay=\(autoplay)&seconds=\(timerSeconds)"

    if let identifier = bookIdentifier {
      actionString += "&identifier=\(identifier)"
    }

    if let encodedActionString = actionString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
      actionString = encodedActionString
    }

    return actionString
  }
}

public enum Command: String {
  case play
  case pause
  case download
  case refresh
  case skipRewind
  case skipForward
  case sleep
  case speed
  case widget
  case fileImport
  case boostVolume
  case chapter
}

public struct Action: Equatable {
  public var command: Command
  public var parameters: [URLQueryItem]

  public init(command: Command, parameters: [URLQueryItem]? = []) {
    self.command = command
    self.parameters = parameters ?? []
  }

  public func getQueryValue(for key: String) -> String? {
    return self.parameters.first { $0.name == key }?.value
  }
}

public extension TimeInterval {
  init(_ option: TimerOption) {
    switch option {
    case .cancel:           self = -1
    case .fiveMinutes:      self = 300
    case .tenMinutes:       self = 600
    case .fifteenMinutes:   self = 900
    case .thirtyMinutes:    self = 1800
    case .fortyFiveMinutes: self = 2700
    case .oneHour:          self = 3600
    case .endChapter:       self = -2
    default:                self = 0
    }
  }

  func toTimerOption() -> TimerOption? {
    switch self {
    case -1:   return .cancel
    case -2:   return .endChapter
    case 300:  return .fiveMinutes
    case 600:  return .tenMinutes
    case 900:  return .fifteenMinutes
    case 1800: return .thirtyMinutes
    case 2700: return .fortyFiveMinutes
    case 3600: return .oneHour
    default:   return nil
    }
  }

  // utility function to transform seconds to format MM:SS or HH:MM:SS
  func toFormattedTime() -> String {
    let durationFormatter = DateComponentsFormatter()

    durationFormatter.unitsStyle = .positional
    durationFormatter.allowedUnits = [.minute, .second]
    durationFormatter.zeroFormattingBehavior = .pad
    durationFormatter.collapsesLargestUnit = false

    if abs(self) > 3599.0 {
      durationFormatter.allowedUnits = [.hour, .minute, .second]
    }

    return durationFormatter.string(from: self)!
  }

  func toFormattedDuration(unitsStyle: DateComponentsFormatter.UnitsStyle = .short) -> String {
    let durationFormatter = DateComponentsFormatter()

    durationFormatter.unitsStyle = unitsStyle
    durationFormatter.allowedUnits = [.minute, .second]
    durationFormatter.collapsesLargestUnit = true

    return durationFormatter.string(from: self)!
  }

  func toFormattedTotalDuration(allowedUnits: NSCalendar.Unit = [.hour, .minute, .second]) -> String {
    let durationFormatter = DateComponentsFormatter()

    durationFormatter.unitsStyle = .abbreviated
    durationFormatter.allowedUnits = allowedUnits
    durationFormatter.collapsesLargestUnit = false
    durationFormatter.allowsFractionalUnits = true

    return durationFormatter.string(from: self)!
  }

  /// Truncates the time to the specified number of decimal places
  func truncated(at place: Int = 5) -> TimeInterval {
    let multiplier = (pow(10, place) as NSNumber).doubleValue

    return Double(Int(self * multiplier)) / multiplier
  }
}
