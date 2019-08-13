//
// Extensions.swift
// BookPlayer
//
// Created by Gianni Carlo on 3/10/17.
// Copyright © 2017 Tortuga Power. All rights reserved.
//

import UIKit

extension Notification.Name {
    static let processingFile = Notification.Name("com.tortugapower.audiobookplayer.file.process")
    static let newFileUrl = Notification.Name("com.tortugapower.audiobookplayer.file.new")
    static let importOperation = Notification.Name("com.tortugapower.audiobookplayer.operation.new")
    static let requestReview = Notification.Name("com.tortugapower.audiobookplayer.requestreview")
    static let skipIntervalsChange = Notification.Name("com.tortugapower.audiobookplayer.settings.skip")
    static let reloadData = Notification.Name("com.tortugapower.audiobookplayer.reloaddata")
    static let playerPresented = Notification.Name("com.tortugapower.audiobookplayer.player.presented")
    static let playerDismissed = Notification.Name("com.tortugapower.audiobookplayer.player.dismissed")
    static let themeChange = Notification.Name("com.tortugapower.audiobookplayer.theme.change")
    static let donationMade = Notification.Name("com.tortugapower.audiobookplayer.donation.made")
}
