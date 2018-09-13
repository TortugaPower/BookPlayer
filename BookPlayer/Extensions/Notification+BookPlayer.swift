//
// Extensions.swift
// BookPlayer
//
// Created by Gianni Carlo on 3/10/17.
// Copyright © 2017 Tortuga Power. All rights reserved.
//

import UIKit

extension Notification.Name {
    public static let processingFile = Notification.Name("com.tortugapower.audiobookplayer.file.process")
    public static let newFileUrl = Notification.Name("com.tortugapower.audiobookplayer.file.new")
    public static let importOperation = Notification.Name("com.tortugapower.audiobookplayer.operation.new")
    public static let requestReview = Notification.Name("com.tortugapower.audiobookplayer.requestreview")
    public static let updatePercentage = Notification.Name("com.tortugapower.audiobookplayer.book.percentage")
    public static let updateChapter = Notification.Name("com.tortugapower.audiobookplayer.book.chapter")
    public static let bookReady = Notification.Name("com.tortugapower.audiobookplayer.book.ready")
    public static let bookPlayed = Notification.Name("com.tortugapower.audiobookplayer.book.play")
    public static let bookPaused = Notification.Name("com.tortugapower.audiobookplayer.book.pause")
    public static let bookStopped = Notification.Name("com.tortugapower.audiobookplayer.book.stop")
    public static let bookEnd = Notification.Name("com.tortugapower.audiobookplayer.book.end")
    public static let bookChange = Notification.Name("com.tortugapower.audiobookplayer.book.change")
    public static let bookPlaying = Notification.Name("com.tortugapower.audiobookplayer.book.playback")
    public static let skipIntervalsChange = Notification.Name("com.tortugapower.audiobookplayer.settings.skip")
    public static let reloadData = Notification.Name("com.tortugapower.audiobookplayer.reloaddata")
    public static let playerPresented = Notification.Name("com.tortugapower.audiobookplayer.player.presented")
    public static let playerDismissed = Notification.Name("com.tortugapower.audiobookplayer.player.dismissed")
}
