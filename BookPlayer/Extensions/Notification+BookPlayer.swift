//
// Extensions.swift
// BookPlayer
//
// Created by Gianni Carlo on 3/10/17.
// Copyright © 2017 Tortuga Power. All rights reserved.
//

import UIKit

extension Notification.Name {
    static let processingFile = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).file.process")
    static let newFileUrl = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).file.new")
    static let downloadProgress = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).download.progress")
    static let importOperation = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).operation.new")
    static let requestReview = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).requestreview")
    static let skipIntervalsChange = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).settings.skip")
    static let reloadData = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).reloaddata")
    static let playerPresented = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).player.presented")
    static let playerDismissed = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).player.dismissed")
    static let themeChange = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).theme.change")
    static let donationMade = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).donation.made")
    static let timerSelected = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).timer.new")
    static let importOperationCancelled = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).operation.cancelled")
}
