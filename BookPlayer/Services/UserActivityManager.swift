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
import Intents

class UserActivityManager {
  let libraryService: LibraryServiceProtocol
  var currentActivity: NSUserActivity
  var playbackRecord: PlaybackRecord?
  private var referenceWorkItem: DispatchWorkItem?
  let encoder = JSONEncoder()
  let decoder = JSONDecoder()

  init(libraryService: LibraryServiceProtocol) {
    self.libraryService = libraryService

    let intent = INPlayMediaIntent()
    let interaction = INInteraction(intent: intent, response: nil)
    interaction.donate(completion: nil)
    let activity = NSUserActivity(activityType: Constants.UserActivityPlayback)
    activity.title = "siri_activity_title".localized
    activity.isEligibleForPrediction = true
    activity.persistentIdentifier = NSUserActivityPersistentIdentifier(Constants.UserActivityPlayback)
    activity.suggestedInvocationPhrase = "siri_invocation_phrase".localized
    activity.isEligibleForSearch = true

    self.currentActivity = activity
  }

  func resumePlaybackActivity() {
    self.currentActivity.becomeCurrent()

    self.playbackRecord = self.libraryService.getCurrentPlaybackRecord()

    guard let record = self.playbackRecord else { return }

    guard !Calendar.current.isDate(record.date, inSameDayAs: Date()) else { return }

    self.playbackRecord = self.libraryService.getCurrentPlaybackRecord()
  }

  func stopPlaybackActivity() {
    self.currentActivity.resignCurrent()
    self.playbackRecord = nil
  }

  func recordTime() {
    guard let record = self.playbackRecord else { return }

    self.libraryService.recordTime(record)

    referenceWorkItem?.cancel()

    let workItem = DispatchWorkItem {
      self.storeRecordInDefaults(record)
    }

    referenceWorkItem = workItem

    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: workItem)
  }

  func storeRecordInDefaults(_ record: PlaybackRecord) {
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
