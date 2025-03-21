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
    let (items, theme) = try getItemsFromDefaults()

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

  func getItemsFromDefaults() throws -> ([PlayableItem], SimpleTheme) {
    guard
      let itemsData = UserDefaults.sharedDefaults.data(forKey: Constants.UserDefaults.sharedWidgetLastPlayedItems),
      let items = try? decoder.decode([PlayableItem].self, from: itemsData)
    else {
      throw BookPlayerError.emptyResponse
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
