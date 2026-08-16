//
//  Notification+BookPlayerKit.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
//

import UIKit

extension Notification.Name {
  private static let bundleIdentifier: String = Bundle.main.bundleIdentifier!
  public static let chapterChange = Notification.Name("\(bundleIdentifier).book.chapter")
  public static let bookPlayed = Notification.Name("\(bundleIdentifier).book.play")
  public static let bookPaused = Notification.Name("\(bundleIdentifier).book.pause")
  public static let bookEnd = Notification.Name("\(bundleIdentifier).book.end")
  public static let bookPlaying = Notification.Name("\(bundleIdentifier).book.playback")
  public static let bookReady = Notification.Name("\(bundleIdentifier).book.ready")
  public static let messageReceived = Notification.Name("\(bundleIdentifier).watch.message")
  public static let accountUpdate = Notification.Name("\(bundleIdentifier).account.update")
  public static let logout = Notification.Name("\(bundleIdentifier).account.logout")
  public static let folderProgressUpdated = Notification.Name("\(bundleIdentifier).folder.progress.update")
  public static let uploadProgressUpdated = Notification.Name("\(bundleIdentifier).upload.progress.update")
  public static let uploadCompleted = Notification.Name("\(bundleIdentifier).upload.completed")
  public static let listeningProgressChanged = Notification.Name("\(bundleIdentifier).listening.progress.changed")
  
}
