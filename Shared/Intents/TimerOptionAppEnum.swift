//
//  TimerOptionAppEnum.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/9/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import Foundation
import AppIntents

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
enum TimerOptionAppEnum: String, AppEnum {
    case cancel
    case fiveMinutes
    case tenMinutes
    case fifteenMinutes
    case thirtyMinutes
    case fortyFiveMinutes
    case oneHour
    case endChapter

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Timer Option")
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .cancel: "Off",
        .fiveMinutes: "5 minutes",
        .tenMinutes: "10 minutes",
        .fifteenMinutes: "15 minutes",
        .thirtyMinutes: "30 minutes",
        .fortyFiveMinutes: "45 minutes",
        .oneHour: "1 hour",
        .endChapter: "End of Chapter"
    ]
}

