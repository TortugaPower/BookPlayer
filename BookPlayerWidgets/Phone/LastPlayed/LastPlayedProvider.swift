//
//  LastPlayedProvider.swift
//  BookPlayerWidgetsPhone
//
//  Created by Gianni Carlo on 30/9/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import WidgetKit

struct LastPlayedProvider: TimelineProvider {
  typealias Entry = RecentlyPlayedEntry

  let decoder = JSONDecoder()

  func placeholder(in context: Context) -> RecentlyPlayedEntry {
    RecentlyPlayedEntry(
      date: Date(),
      items: [],
      currentlyPlaying: nil
    )
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (Entry) -> Void
  ) {
    Task {
      do {
        let entry = try await getEntryForTimeline(
          context: context
        )
        completion(entry)
      } catch {
        completion(placeholder(in: context))
      }
    }
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<Entry>) -> Void
  ) {
    Task {
      do {
        let entry = try await getEntryForTimeline(context: context)

        completion(Timeline(entries: [entry], policy: .never))
      } catch {
        completion(Timeline(entries: [], policy: .never))
      }
    }
  }

  func getEntryForTimeline(
    context: Context
  ) async throws -> RecentlyPlayedEntry {
    let items: [WidgetLibraryItem]
    let theme: SimpleTheme

    /// Attempt to fetch from shared defaults, otherwise default to database
    if let (widgetItems, widgetTheme) = getItemsFromDefaults() {
      items = widgetItems
      theme = widgetTheme
    } else {
      let (widgetItems, widgetTheme) = try await getDataFromDatabase()
      items = widgetItems
      theme = widgetTheme
    }

    let currentlyPlaying = UserDefaults.sharedDefaults.string(
      forKey: Constants.UserDefaults.sharedWidgetNowPlayingPath
    )

    return RecentlyPlayedEntry(
      date: Date(),
      items: items,
      currentlyPlaying: currentlyPlaying,
      theme: theme
    )
  }

  func getDataFromDatabase() async throws -> ([WidgetLibraryItem], SimpleTheme) {
    let stack = try await DatabaseInitializer().loadCoreDataStack()
    let dataManager = DataManager(coreDataStack: stack)
    let libraryService = LibraryService(dataManager: dataManager)

    guard
      let lastPlayedItems = libraryService.getLastPlayedItems(limit: 4)
    else {
      throw BookPlayerError.emptyResponse
    }

    let items = lastPlayedItems.map({
      WidgetLibraryItem(
        relativePath: $0.relativePath,
        title: $0.title,
        details: $0.details
      )
    })

    return (
      items,
      libraryService.getLibraryCurrentTheme() ?? SimpleTheme.getDefaultTheme()
    )
  }

  func getItemsFromDefaults() -> ([WidgetLibraryItem], SimpleTheme)? {
    guard
      let itemsData = UserDefaults.sharedDefaults.data(forKey: Constants.UserDefaults.sharedWidgetLastPlayedItems),
      let items = try? decoder.decode([WidgetLibraryItem].self, from: itemsData)
    else {
      return nil
    }

    let theme: SimpleTheme
    if let themeData = UserDefaults.sharedDefaults.data(
      forKey: Constants.UserDefaults.sharedWidgetTheme
    ), let widgetTheme = try? decoder.decode(SimpleTheme.self, from: themeData) {
      theme = widgetTheme
    } else {
      theme = SimpleTheme.getDefaultTheme()
    }

    return (items, theme)
  }
}
