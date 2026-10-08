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
  let widgetReloadService = WidgetReloadService()

  private var isListeningHistoryEnabled: Bool {
    // App Group so watchOS respects the iPhone Privacy toggle (shared Core Data store).
    !UserDefaults.sharedDefaults.bool(forKey: Constants.UserDefaults.listeningHistoryDisabled)
  }

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

  func resumePlaybackActivity(relativePath: String, title: String) {
    self.currentActivity.becomeCurrent()

    self.playbackRecord = self.libraryService.getCurrentPlaybackRecord()

    if let record = self.playbackRecord,
      !Calendar.current.isDate(record.date, inSameDayAs: Date())
    {
      self.playbackRecord = self.libraryService.getCurrentPlaybackRecord()
    }

    guard isListeningHistoryEnabled else { return }

    let presentation = libraryService.listeningHistoryPresentation(
      for: relativePath,
      fallbackTitle: title
    )
    self.libraryService.startListeningSession(
      relativePath: relativePath,
      title: presentation.title,
      subtitle: presentation.subtitle,
      artworkRelativePath: presentation.artworkRelativePath
    )
  }

  func stopPlaybackActivity() {
    self.currentActivity.resignCurrent()
    self.playbackRecord = nil
    self.libraryService.endListeningSession()
  }

  func recordTime() {
    guard let record = self.playbackRecord else { return }

    self.libraryService.recordTime(record)
    if isListeningHistoryEnabled {
      self.libraryService.recordListeningSessionTick()
    }

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
