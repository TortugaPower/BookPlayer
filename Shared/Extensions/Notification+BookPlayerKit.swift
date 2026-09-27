//
//  Notification+BookPlayerKit.swift
//  BookPlayerKit
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
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
  public static let listeningProgressChanged = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).listening.progress.changed")
  public static let newTaskInQueue = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).concurrent.task.queue")
  /// A background URLSession delivered every event iOS held for it (after a relaunch or a
  /// wake). `object` is the session's identifier.
  public static let backgroundSessionFinishedEvents = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).background.session.finished.events")
  /// Books were queued for upload (an import, or the first sync after signing in or
  /// subscribing): the app may keep uploading in the background (a continued task)
  public static let bookUploadsQueued = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).book.uploads.queued")
  /// A queued task was parked on a coded server error and hasn't been reported yet.
  /// `object` is the `QueuedSyncTask` (with its `pause`).
  public static let syncTaskPaused = Notification.Name("\(Bundle.main.configurationString(for: .bundleIdentifier)).sync.task.paused")
}
