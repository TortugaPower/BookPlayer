//
//  RecentBooksProvider.swift
//  BookPlayerWidgetsPhone
//
//  Created by Gianni Carlo on 30/9/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import WidgetKit

struct RecentBooksProvider: TimelineProvider {
  let numberOfBooks = 4

  typealias Entry = LibraryEntry

  func placeholder(in context: Context) -> LibraryEntry {
    return LibraryEntry(
      date: Date(),
      items: [
        SimpleLibraryItem.previewItem(title: "Last played"),
        SimpleLibraryItem.previewItem(title: "Book title"),
        SimpleLibraryItem.previewItem(title: "Book title"),
        SimpleLibraryItem.previewItem(title: "Book title"),
      ]
    )
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (LibraryEntry) -> Void
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
    completion: @escaping (Timeline<LibraryEntry>) -> Void
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

  func getEntryForTimeline(context: Context) async throws -> LibraryEntry {
    let stack = try await DatabaseInitializer().loadCoreDataStack()
    let dataManager = DataManager(coreDataStack: stack)
    let libraryService = LibraryService(dataManager: dataManager)

    guard
      let items = libraryService.getLastPlayedItems(limit: numberOfBooks)
    else {
      throw BookPlayerError.emptyResponse
    }

    let theme = libraryService.getLibraryCurrentTheme() ?? SimpleTheme.getDefaultTheme()

    let entry = LibraryEntry(
      date: Date(),
      items: items,
      theme: theme
    )

    return entry
  }
}
