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
    public static let bookChange = Notification.Name("com.tortugapower.audiobookplayer.book.change")
    public static let bookPlaying = Notification.Name("com.tortugapower.audiobookplayer.book.playback")
}
