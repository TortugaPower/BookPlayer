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
  /// Current location: `.libraryRoot`, `.folder(ref)`, or `.unresolved`.
  let location: SortLocation
  /// Triggered when the user changes the effective sort.
  let onSelectionChange: (EffectiveSort) -> Void
  /// Triggered when the user taps the one-off "Reverse Order" action.
  /// Reverses the current order locally and transitions the sticky sort to `.custom`.
  let onReverseOrder: () -> Void

  /// Bound to the matching UserDefaults key. The view re-renders automatically when
  /// the value changes — including when `PreferencesSyncService` applies a remote pull,
  /// since that ultimately writes to UserDefaults too.
  @AppStorage private var sortRaw: String

  /// Library tab progress indicator: false = wheel (default), true = numeric percentage.
  /// Synced cross-device via `PreferencesSyncService`.
  @AppStorage(
    wrappedValue: false,
    Constants.UserDefaults.libraryDisplayProgressStyle,
    store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)
  )
  private var progressAsPercentage: Bool

  /// Library tab title source: false = parsed title (default), true = original filename.
  /// Synced cross-device via `PreferencesSyncService`.
  @AppStorage(
    wrappedValue: false,
    Constants.UserDefaults.libraryDisplayTitleSource,
    store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)
  )
  private var useOriginalFileName: Bool

  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var theme: ThemeViewModel

  init(
    location: SortLocation,
    onSelectionChange: @escaping (EffectiveSort) -> Void,
    onReverseOrder: @escaping () -> Void
  ) {
    self.location = location
    self.onSelectionChange = onSelectionChange
    self.onReverseOrder = onReverseOrder

    // Pick the matching UserDefaults key for the picker binding.
    // `.unresolved` falls back to the default key only because `@AppStorage`
    // requires a non-empty string here; the picker is `.disabled` in that
    // case so reads never surface and writes never fire.
    let key: String
    switch location {
    case .libraryRoot, .unresolved:
      key = Constants.UserDefaults.librarySortDefault
    case .folder(let ref):
      key = Constants.UserDefaults.librarySort(folderUuid: ref.uuid)
    }
    self._sortRaw = AppStorage(
      wrappedValue: "",
      key,
      store: UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)
    )
  }

  /// Localized title shown on the right side of the menu trigger row, mirroring the
  /// label that `Picker(.menu)` rendered before the menu got a one-off section.
  private var currentSortDisplayKey: LocalizedStringKey {
    switch pickerSelection.wrappedValue {
    case .metadataTitle: return "title_button"
    case .fileName: return "sort_filename_button"
    case .mostRecent: return "sort_most_recent_button"
    case .none: return "sleeptimer_option_custom"
    }
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
          if location == .unresolved {
            // Mid-migration folder (or non-sortable container): the sort
            // re-ranks items locally but is NOT persisted as a sticky pref.
            // Once the folder's UUID materializes the user can re-tap and
            // it'll stick. Render plain Buttons so the UI doesn't suggest
            // a persistent selection.
            oneShotSortRow(.metadataTitle, titleKey: "title_button")
            oneShotSortRow(.fileName, titleKey: "sort_filename_button")
            oneShotSortRow(.mostRecent, titleKey: "sort_most_recent_button")
          } else {
            Menu {
              // Sticky picker — selection persists.
              Picker(selection: pickerSelection) {
                Text("title_button").tag(Optional(SortType.metadataTitle))
                Text("sort_filename_button").tag(Optional(SortType.fileName))
                Text("sort_most_recent_button").tag(Optional(SortType.mostRecent))
                Text("sleeptimer_option_custom").tag(SortType?.none)
              } label: {
                Text("sort_files_title")
              }

              // One-off section: reverses the current order and transitions
              // the sticky sort to `.custom`.
              Section {
                Button {
                  onReverseOrder()
                } label: {
                  Text("sort_reversed_button")
                }
              } header: {
                Text("library_options_quick_actions_title")
              }
            } label: {
              HStack {
                Text("sort_files_title")
                  .bpFont(.body)
                  .foregroundStyle(theme.primaryColor)
                Spacer()
                Text(currentSortDisplayKey)
                  .bpFont(.body)
                  .foregroundStyle(theme.linkColor)
              }
              .contentShape(Rectangle())
            }
          }

          Toggle(isOn: $progressAsPercentage) {
            Text("library_options_progress_as_percentage_title")
              .bpFont(.body)
          }

          Toggle(isOn: $useOriginalFileName) {
            Text("library_options_original_filename_title")
              .bpFont(.body)
          }
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

  /// Single-tap action for `.unresolved` locations. The user picks a sort,
  /// items are re-ranked locally via `onSelectionChange → handleSort →
  /// sortContents(at:by:)`, and the resolver no-ops the pref write because
  /// the location resolves to `.unresolved`.
  @ViewBuilder
  private func oneShotSortRow(
    _ sort: SortType,
    titleKey: LocalizedStringKey
  ) -> some View {
    Button {
      onSelectionChange(.automatic(sort))
    } label: {
      Text(titleKey)
        .foregroundStyle(theme.primaryColor)
    }
  }
}
