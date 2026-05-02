//
//  LibraryOptionsView.swift
//  BookPlayer
//
//  Library-options sheet hosted from `ItemListView`'s toolbar.
//  Currently surfaces the sticky-sort picker; intended to grow with
//  future per-location preferences (display style, grouping, etc.).
//

import BookPlayerKit
import SwiftUI

struct LibraryOptionsView: View {
  /// Current location: `nil` for the library root, otherwise the folder ref.
  let location: LibraryItemRef?
  /// Whether sticky sort can be applied here (false for placeholder UUIDs).
  let canApplyStickySort: Bool
  /// Triggered when the user changes the effective sort.
  let onSelectionChange: (EffectiveSort) -> Void

  /// Bound to the matching UserDefaults key. The view re-renders automatically when
  /// the value changes — including when `PreferencesSyncService` applies a remote pull,
  /// since that ultimately writes to UserDefaults too.
  @AppStorage private var sortRaw: String

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var theme: ThemeViewModel

  init(
    location: LibraryItemRef?,
    canApplyStickySort: Bool,
    onSelectionChange: @escaping (EffectiveSort) -> Void
  ) {
    self.location = location
    self.canApplyStickySort = canApplyStickySort
    self.onSelectionChange = onSelectionChange

    let key: String
    if let location, Constants.isRealUuid(location.uuid) {
      key = Constants.UserDefaults.librarySort(folderUuid: location.uuid)
    } else {
      key = Constants.UserDefaults.librarySortDefault
    }
    self._sortRaw = AppStorage(
      wrappedValue: "",
      key,
      store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)
    )
  }

  /// Picker selection bound to the resolved effective sort:
  /// - `.automatic(sort)` → the matching `SortType`
  /// - `.custom` (or no pref set) → `nil`, which matches the explicit "Custom" tag
  ///
  /// Setter is only invoked on user input; programmatic changes (remote pull) flow
  /// through `@AppStorage` re-rendering the picker without firing the setter.
  private var pickerSelection: Binding<SortType?> {
    Binding(
      get: {
        if case .automatic(let sort) = EffectiveSort(rawValue: sortRaw) ?? .custom {
          return sort
        }
        return nil
      },
      set: { newValue in
        if let sort = newValue {
          onSelectionChange(.automatic(sort))
        } else {
          onSelectionChange(.custom)
        }
      }
    )
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          Picker(selection: pickerSelection) {
            Text("title_button").tag(Optional(SortType.metadataTitle))
            Text("sort_filename_button").tag(Optional(SortType.fileName))
            Text("sort_most_recent_button").tag(Optional(SortType.mostRecent))
            Text("sleeptimer_option_custom").tag(SortType?.none)
          } label: {
            Text("sort_files_title")
              .bpFont(.body)
          }
          .pickerStyle(.menu)
          .disabled(!canApplyStickySort)
        }
      }
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      .navigationTitle("options_button")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .foregroundStyle(theme.linkColor)
          }
        }
      }
    }
    .presentationDetents([.medium])
  }
}
