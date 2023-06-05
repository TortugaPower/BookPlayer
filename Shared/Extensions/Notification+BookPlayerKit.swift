//
//  Notification+BookPlayerKit.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import UIKit

extension Notification.Name {
  public static let chapterChange = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.chapter")
  public static let bookPlayed = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.play")
  public static let bookPaused = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.pause")
  public static let bookEnd = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.end")
  public static let bookPlaying = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.playback")
  public static let bookReady = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.ready")
  public static let messageReceived = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).watch.message")
  public static let accountUpdate = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).account.update")
  public static let logout = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).account.logout")
  public static let folderProgressUpdated = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).folder.progress.update")
  public static let uploadProgressUpdated = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).upload.progress.update")
  public static let uploadCompleted = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).upload.completed")
  public static let recreateQueue = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).queue.recreate")
  public static let jobScheduled = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).job.scheduled")
  public static let jobTerminated = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).job.terminated")
}
