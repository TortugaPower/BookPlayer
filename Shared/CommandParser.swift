//
//  CommandParser.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Foundation
import Intents

public class CommandParser {
    public class func parse(_ activity: NSUserActivity) -> Action? {
        if let intent = activity.interaction?.intent {
            return self.parse(intent)
        } else if activity.activityType == "\(Bundle.main.bundleIdentifier!).activity.playback" {
            return Action(command: .play)
        }

        return nil
    }

    public class func parse(_ intent: INIntent) -> Action? {
        if let sleepIntent = intent as? SleepTimerIntent {
            var queryItem: URLQueryItem

            if let seconds = sleepIntent.seconds {
                queryItem = URLQueryItem(name: "seconds", value: seconds.stringValue)
            } else {
                let seconds = TimeParser.getSeconds(from: sleepIntent.option)
                queryItem = URLQueryItem(name: "seconds", value: String(seconds))
            }

            return Action(command: .sleep, parameters: [queryItem])
        }

        if intent is INPlayMediaIntent {
            return Action(command: .play)
        }

        return nil
    }

    public class func parse(_ url: URL) -> Action? {
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

    public class func parse(_ message: [String: Any]) -> Action? {
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

    public class func createActionString(from command: Command, parameters: [URLQueryItem]) -> String {
        var actionString = "bookplayer://\(command.rawValue)?"

        actionString = parameters.reduce(actionString) { (text, item) -> String in
            guard let value = item.value else { return text }

            return "\(text)\(item.name)=\(value)&"
        }

        return actionString
    }
}

public enum Command: String {
    case play
    case download
    case refresh
    case skipRewind
    case skipForward
    case sleep
}

public struct Action {
    public var command: Command
    public var parameters: [URLQueryItem]

    public func getParametersDictionary() -> [String: String] {
        var payload = ["command": self.command.rawValue]

        for item in self.parameters {
            payload[item.name] = item.value ?? ""
        }

        return payload
    }

    public init(command: Command, parameters: [URLQueryItem]? = []) {
        self.command = command
        self.parameters = parameters ?? []
    }

    public func getQueryValue(for key: String) -> String? {
        return self.parameters.filter { $0.name == key }.first?.value
    }
}

public class TimeParser {
    public class func getSeconds(from option: TimerOption) -> TimeInterval {
        switch option {
        case .cancel:
            return -1
        case .fiveMinutes:
            return 300
        case .tenMinutes:
            return 600
        case .fifteenMinutes:
            return 900
        case .thirtyMinutes:
            return 1800
        case .fortyFiveMinutes:
            return 2700
        case .oneHour:
            return 3600
        case .endChapter:
            return -2
        default:
            return 0
        }
    }

    public class func getTimerOption(from seconds: TimeInterval) -> TimerOption {
        var option: TimerOption

        switch seconds {
        case -1:
            option = .cancel
        case 300:
            option = .fiveMinutes
        case 600:
            option = .tenMinutes
        case 900:
            option = .fifteenMinutes
        case 1800:
            option = .thirtyMinutes
        case 2700:
            option = .fortyFiveMinutes
        case 3600:
            option = .oneHour
        default:
            option = .endChapter
        }

        return option
    }
}
