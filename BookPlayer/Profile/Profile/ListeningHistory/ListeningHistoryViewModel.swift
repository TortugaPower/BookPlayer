//
//  ListeningHistoryViewModel.swift
//  BookPlayer
//
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Foundation
import SwiftUI

enum ListeningHistoryDateScope: String, CaseIterable, Identifiable {
  case all
  case today
  case week
  case month

  var id: String { rawValue }

  var titleKey: String {
    switch self {
    case .all:
      return "listening_history_filter_all_title"
    case .today:
      return "listening_history_filter_today_title"
    case .week:
      return "listening_history_filter_week_title"
    case .month:
      return "listening_history_filter_month_title"
    }
  }

  func dateRange(now: Date = Date(), calendar: Calendar = .current) -> (start: Date?, end: Date?) {
    switch self {
    case .all:
      return (nil, nil)
    case .today:
      let start = calendar.startOfDay(for: now)
      let end = calendar.date(byAdding: .day, value: 1, to: start)
      return (start, end)
    case .week:
      let start = calendar.date(byAdding: .day, value: -7, to: now)
      return (start, nil)
    case .month:
      let start = calendar.date(byAdding: .day, value: -30, to: now)
      return (start, nil)
    }
  }
}

struct ListeningHistoryDaySection: Identifiable, Hashable {
  let id: Date
  let title: String
  let sessions: [SimpleListeningSession]
}

@MainActor
final class ListeningHistoryViewModel: ObservableObject {
  @Published var sections: [ListeningHistoryDaySection] = []
  @Published var searchText: String = ""
  @Published var dateScope: ListeningHistoryDateScope = .all
  @Published var editMode: EditMode = .inactive
  @Published var selectedIds: Set<String> = []
  @Published private(set) var isHistoryDisabled: Bool = false

  private let libraryService: LibraryServiceProtocol
  private let calendar: Calendar
  private let defaults: UserDefaults

  var isEmpty: Bool {
    sections.isEmpty
  }

  var hasSelection: Bool {
    !selectedIds.isEmpty
  }

  init(
    libraryService: LibraryServiceProtocol,
    calendar: Calendar = .current,
    defaults: UserDefaults = .sharedDefaults
  ) {
    self.libraryService = libraryService
    self.calendar = calendar
    self.defaults = defaults
  }

  func reload() {
    isHistoryDisabled = defaults.bool(forKey: Constants.UserDefaults.listeningHistoryDisabled)

    let range = dateScope.dateRange(calendar: calendar)
    var sessions = libraryService.getListeningSessions(
      from: range.start,
      to: range.end,
      relativePath: nil,
      limit: nil,
      offset: nil
    )

    let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
      sessions = sessions.filter { session in
        session.itemTitle.localizedCaseInsensitiveContains(trimmed)
          || session.relativePath.localizedCaseInsensitiveContains(trimmed)
          || (session.subtitle?.localizedCaseInsensitiveContains(trimmed) ?? false)
      }
    }

    sections = Self.groupSessionsByDay(sessions, calendar: calendar)
    selectedIds = selectedIds.intersection(Set(sessions.map(\.id)))
  }

  func toggleSelection(for id: String) {
    if selectedIds.contains(id) {
      selectedIds.remove(id)
    } else {
      selectedIds.insert(id)
    }
  }

  func deleteSessions(ids: [String]) {
    guard !ids.isEmpty else { return }
    libraryService.deleteListeningSessions(ids: ids)
    selectedIds.subtract(ids)
    reload()
  }

  func deleteSelected() {
    deleteSessions(ids: Array(selectedIds))
    editMode = .inactive
  }

  func clearAll() {
    libraryService.deleteAllListeningSessions()
    selectedIds.removeAll()
    editMode = .inactive
    reload()
  }

  func presentation(for session: SimpleListeningSession) -> ListeningHistoryPresentation {
    // Prefer denormalized snapshot written at session start.
    session.presentation
  }

  func artworkItem(for presentation: ListeningHistoryPresentation) -> SimpleLibraryItem? {
    libraryService.getSimpleItem(with: presentation.artworkRelativePath)
      ?? libraryService.getSimpleItem(with: presentation.loadRelativePath)
  }

  func canLoad(_ presentation: ListeningHistoryPresentation) -> Bool {
    libraryService.getSimpleItem(with: presentation.loadRelativePath) != nil
  }

  static func groupSessionsByDay(
    _ sessions: [SimpleListeningSession],
    calendar: Calendar = .current,
    now: Date = Date()
  ) -> [ListeningHistoryDaySection] {
    let grouped = Dictionary(grouping: sessions) { session in
      calendar.startOfDay(for: session.startedAt)
    }

    return grouped.keys.sorted(by: >).compactMap { dayStart in
      guard let daySessions = grouped[dayStart] else { return nil }
      return ListeningHistoryDaySection(
        id: dayStart,
        title: daySectionTitle(for: dayStart, calendar: calendar, now: now),
        sessions: daySessions.sorted { $0.startedAt > $1.startedAt }
      )
    }
  }

  private static func daySectionTitle(for dayStart: Date, calendar: Calendar, now: Date) -> String {
    if calendar.isDateInToday(dayStart) {
      return "listening_history_today_title".localized
    }
    if calendar.isDateInYesterday(dayStart) {
      return "listening_history_yesterday_title".localized
    }

    let formatter = DateFormatter()
    formatter.doesRelativeDateFormatting = false
    if calendar.component(.year, from: dayStart) == calendar.component(.year, from: now) {
      formatter.setLocalizedDateFormatFromTemplate("MMMMd")
    } else {
      formatter.setLocalizedDateFormatFromTemplate("yMMMMd")
    }
    return formatter.string(from: dayStart)
  }
}
