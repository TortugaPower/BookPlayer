//
//  Notification+BookPlayerKit.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import UIKit

extension Notification.Name {
    public static let updatePercentage = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.percentage")
    public static let chapterChange = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.chapter")
    public static let bookReady = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.ready")
    public static let bookPlayed = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.play")
    public static let bookPaused = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.pause")
    public static let bookStopped = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.stop")
    public static let bookEnd = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.end")
    public static let bookDelete = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.delete")
    public static let bookChange = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.change")
    public static let bookPlaying = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.playback")
    public static let contextUpdate = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).watch.sync")
    public static let messageReceived = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).watch.message")
    public static let timerStart = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).sleeptimer.start")
    public static let timerProgress = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).sleeptimer.progress")
    public static let timerEnd = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).sleeptimer.end")
}
