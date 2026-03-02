//
//  LRCParser.swift
//  BookPlayer
//
//  Created by Codex on 3/2/26.
//

import Foundation

enum LRCParserError: LocalizedError {
    case noTimedLines

    var errorDescription: String? {
        switch self {
        case .noTimedLines:
            return "Unable to find any timed lines in this LRC file."
        }
    }
}

enum LRCParser {
    static func parse(_ contents: String) throws -> [TranscriptLine] {
        var lines = [TranscriptLine]()

        for rawLine in contents.split(whereSeparator: \.isNewline) {
            let line = String(rawLine)
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            var timestamps = [TimeInterval]()
            var remainder = trimmedLine

            while remainder.first == "[" {
                guard let closingIndex = remainder.firstIndex(of: "]") else { break }
                let tag = String(remainder[remainder.index(after: remainder.startIndex)..<closingIndex])
                if let time = parseTimestamp(tag) {
                    timestamps.append(time)
                }
                remainder = String(remainder[remainder.index(after: closingIndex)...])
            }

            let text = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !timestamps.isEmpty, !text.isEmpty else { continue }

            for time in timestamps {
                lines.append(TranscriptLine(time: time, text: text))
            }
        }

        guard !lines.isEmpty else {
            throw LRCParserError.noTimedLines
        }

        return lines.sorted { $0.time < $1.time }
    }

    private static func parseTimestamp(_ token: String) -> TimeInterval? {
        let cleanToken = token.replacingOccurrences(of: ",", with: ".")
        let parts = cleanToken.split(separator: ":")
        guard parts.count == 2 || parts.count == 3 else { return nil }

        let secondsPart = parts.last ?? ""
        guard let seconds = Double(secondsPart) else { return nil }

        if parts.count == 2 {
            guard let minutes = Double(parts[0]) else { return nil }
            return (minutes * 60) + seconds
        }

        guard let hours = Double(parts[0]), let minutes = Double(parts[1]) else { return nil }
        return (hours * 3600) + (minutes * 60) + seconds
    }
}
