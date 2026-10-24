//
//  UserActivityManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/29/18.
//  Copyright © 2018 BookPlayer LLC. All rights reserved.
//

#if os(watchOS)
  import BookPlayerWatchKit
#else
  import BookPlayerKit
#endif
import Combine
import Foundation

/// Records the time listened per day (`PlaybackRecord`) and hands the last week to the Time Listened widget
class UserActivityManager {
  let libraryService: LibraryServiceProtocol
  var playbackRecord: PlaybackRecord?
  private var referenceWorkItem: DispatchWorkItem?
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()
  let widgetReloadService = WidgetReloadService()

  init(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService
  }

  func resumePlaybackActivity() {
    self.playbackRecord = self.libraryService.getCurrentPlaybackRecord()

    guard let record = self.playbackRecord else { return }

    guard !Calendar.current.isDate(record.date, inSameDayAs: Date()) else { return }

    self.playbackRecord = self.libraryService.getCurrentPlaybackRecord()
  }

  func stopPlaybackActivity() {
    self.playbackRecord = nil
  }

  func recordTime() {
    guard let record = self.playbackRecord else { return }

    self.libraryService.recordTime(record)

    scheduleStoreRecordInDefaults()
  }

  func scheduleStoreRecordInDefaults() {
    guard referenceWorkItem == nil else { return }

    let workItem = DispatchWorkItem {
      self.storeRecordInDefaults()
      self.widgetReloadService.reloadWidget(.timeListenedWidget)
      self.referenceWorkItem = nil
    }

    referenceWorkItem = workItem

    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: workItem)
  }

  func storeRecordInDefaults() {
    guard let record = playbackRecord else { return }

    var widgetItems: [SimplePlaybackRecord] = [
      .init(from: record)
    ]
    if let itemsData = UserDefaults.sharedDefaults.data(forKey: Constants.UserDefaults.sharedWidgetPlaybackRecords),
      let items = try? decoder.decode([SimplePlaybackRecord].self, from: itemsData)
    {
      widgetItems.append(contentsOf: items.filter({ $0.date != record.date }))
      widgetItems = Array(widgetItems.prefix(7))
    }

    guard let data = try? encoder.encode(widgetItems) else {
      return
    }

    UserDefaults.sharedDefaults.set(data, forKey: Constants.UserDefaults.sharedWidgetPlaybackRecords)
  }
}
