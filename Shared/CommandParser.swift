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

        var parameters = [URLQueryItem]()

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
            let queryItems = components.queryItems {
            parameters = queryItems
        }

        guard let command = Command(rawValue: host) else { return nil }

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
    case open
}

public struct Action {
    public var command: Command
    public var parameters: [URLQueryItem]

    public init(command: Command, parameters: [URLQueryItem]? = []) {
        self.command = command
        self.parameters = parameters ?? []
    }
}
