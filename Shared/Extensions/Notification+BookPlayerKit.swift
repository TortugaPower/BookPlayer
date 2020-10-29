//
//  Notification+BookPlayerKit.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import UIKit

extension Notification.Name {
    public static let updatePercentage = Notification.Name("com.tortugapower.audiobookplayer.book.percentage")
    public static let chapterChange = Notification.Name("com.tortugapower.audiobookplayer.book.chapter")
    public static let bookReady = Notification.Name("com.tortugapower.audiobookplayer.book.ready")
    public static let bookPlayed = Notification.Name("com.tortugapower.audiobookplayer.book.play")
    public static let bookPaused = Notification.Name("com.tortugapower.audiobookplayer.book.pause")
    public static let bookStopped = Notification.Name("com.tortugapower.audiobookplayer.book.stop")
    public static let bookEnd = Notification.Name("com.tortugapower.audiobookplayer.book.end")
    public static let bookDelete = Notification.Name("com.tortugapower.audiobookplayer.book.delete")
    public static let bookChange = Notification.Name("com.tortugapower.audiobookplayer.book.change")
    public static let bookPlaying = Notification.Name("com.tortugapower.audiobookplayer.book.playback")
    public static let contextUpdate = Notification.Name("com.tortugapower.audiobookplayer.watch.sync")
    public static let messageReceived = Notification.Name("com.tortugapower.audiobookplayer.watch.message")
    public static let timerStart = Notification.Name("com.tortugapower.audiobookplayer.sleeptimer.start")
    public static let timerProgress = Notification.Name("com.tortugapower.audiobookplayer.sleeptimer.progress")
    public static let timerEnd = Notification.Name("com.tortugapower.audiobookplayer.sleeptimer.end")
}
