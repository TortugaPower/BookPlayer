//
//  IntegrationCustomHeadersSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/20/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct IntegrationCustomHeadersSectionView: View {
  @Binding var customHeaders: [CustomHeaderEntry]

  /// Called when the user commits an edit — on Return key, when focus leaves the
  /// field, when a row is deleted, or when the section disappears. The caller
  /// persists the current state. `nil` means "don't persist yet" (e.g. during
  /// initial connect/sign-in, where the full form state is written once at sign-in).
  var onCommit: (() -> Void)?

  @EnvironmentObject var theme: ThemeViewModel

  private enum FocusedField: Hashable {
    case key(UUID)
    case value(UUID)
  }

  @FocusState private var focusedField: FocusedField?

  /// IDs of rows that `customHeadersDictionary()` will drop — either because
  /// the entry is rejected by `CustomHeaderEntry.normalized`, or because a
  /// later row with the same normalized key will overwrite it. Used to strike
  /// through the key field as a hint.
  private var droppedEntryIDs: Set<UUID> {
    var dropped: Set<UUID> = []
    var lastWinner: [String: UUID] = [:]
    for entry in customHeaders {
      guard let pair = entry.normalized else {
        dropped.insert(entry.id)
        continue
      }
      if let priorID = lastWinner[pair.key] {
        dropped.insert(priorID)
      }
      lastWinner[pair.key] = entry.id
    }
    return dropped
  }

  /// True when the row should visually strike through its key. Suppressed while
  /// the row is being edited so the user doesn't see "crossed-out" text mid-typing.
  private func shouldStrikethrough(_ entry: CustomHeaderEntry) -> Bool {
    guard droppedEntryIDs.contains(entry.id) else { return false }
    return focusedField != .key(entry.id) && focusedField != .value(entry.id)
  }

  var body: some View {
    ThemedSection {
      ForEach($customHeaders) { $entry in
        HStack(alignment: .center, spacing: 8) {
          VStack(alignment: .leading, spacing: 4) {
            TextField(
              "integration_custom_headers_key_placeholder".localized,
              text: $entry.key
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .key(entry.id))
            .onSubmit { onCommit?() }
            .strikethrough(shouldStrikethrough(entry))

            TextField(
              "integration_custom_headers_value_placeholder".localized,
              text: $entry.value
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .value(entry.id))
            .onSubmit { onCommit?() }
          }

          Button {
            let removedID = entry.id
            customHeaders.removeAll { $0.id == removedID }
            onCommit?()
          } label: {
            Image(systemName: "trash")
              .foregroundStyle(.red)
              .padding(.horizontal, 4)
              .contentShape(Rectangle())
          }
          .buttonStyle(.borderless)
          .accessibilityLabel("delete_button".localized)
        }
        .padding(.vertical, 2)
      }

      Button {
        let entry = CustomHeaderEntry()
        customHeaders.append(entry)
        focusedField = .key(entry.id)
      } label: {
        Label(
          "integration_custom_headers_add_button".localized,
          systemImage: "plus.circle"
        )
        .foregroundStyle(theme.linkColor)
      }
    } header: {
      Text("integration_custom_headers_title".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("integration_custom_headers_footer".localized)
        .foregroundStyle(theme.secondaryColor)
    }
    .onChange(of: focusedField) { oldValue, _ in
      // Focus left a field — persist whatever was being typed.
      if oldValue != nil {
        onCommit?()
      }
    }
    .onDisappear {
      onCommit?()
    }
  }
}
