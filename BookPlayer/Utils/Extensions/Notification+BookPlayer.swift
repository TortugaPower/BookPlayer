//
// Extensions.swift
// BookPlayer
//
// Created by Gianni Carlo on 3/10/17.
// Copyright © 2017 BookPlayer LLC. All rights reserved.
//

import UIKit

extension Notification.Name {
  static let processingFile = Notification.Name("\(Bundle.main.bundleIdentifier!).file.process")
  static let downloadProgress = Notification.Name("\(Bundle.main.bundleIdentifier!).download.progress")
  static let downloadEnd = Notification.Name("\(Bundle.main.bundleIdentifier!).download.end")
  static let requestReview = Notification.Name("\(Bundle.main.bundleIdentifier!).requestreview")
  static let donationMade = Notification.Name("\(Bundle.main.bundleIdentifier!).donation.made")
  /// Posted when the fullscreen video controller finishes tearing down. The inline
  /// surface shares the same `AVPlayer`; the fullscreen surface takes over its video
  /// output, so the inline surface must reclaim rendering once fullscreen is gone.
  static let videoFullscreenDidDismiss = Notification.Name("\(Bundle.main.bundleIdentifier!).video.fullscreen.dismissed")
}
