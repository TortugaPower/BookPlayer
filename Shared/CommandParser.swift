//
//  CommandParser.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Foundation

public class CommandParser {
    public class func parse(_ url: URL) -> Action? {
        guard let host = url.host else {
            // Maintain empty action as Play
            return Action(command: .play)
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

    public class func parse(_ message: [String: Any]) -> Action {
        guard let commandString = message["command"] as? String,
            let command = Command(rawValue: commandString) else { return Action(command: .play) }

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

    public init(command: Command, parameters: [URLQueryItem]? = []) {
        self.command = command
        self.parameters = parameters ?? []
    }

    public func getQueryValue(for key: String) -> String? {
        return self.parameters.filter { $0.name == key }.first?.value
    }
}
