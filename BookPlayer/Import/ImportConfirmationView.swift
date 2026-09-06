//
//  ImportConfirmationView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/9/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

/// One removable row of an import confirmation list. Flow-agnostic: the external
/// flow renders waveform rows from its batch; the file-import flow (a future
/// adoption replacing ImportViewController) adds folder icons and "N files"
/// subtitles from its own view model.
struct ImportConfirmationRow: Identifiable {
  let id: String
  let icon: String
  let title: String
  var subtitle: String?
}

/// The reusable import-confirmation shell: header, description, count, a removable
/// row list, and cancel/confirm actions. Deliberately presentation-agnostic —
/// dismissal, destructive-cancel semantics, and row sourcing belong to the flow
/// wrappers (see `ExternalImportView`; `ImportViewController` is the future
/// adopter for the file flow, whose ImportViewModel is already an
/// ObservableObject publishing its rows).
struct ImportConfirmationView: View {
  let rows: [ImportConfirmationRow]
  let onRemove: (ImportConfirmationRow.ID) -> Void
  let onConfirm: () -> Void
  let onCancel: () -> Void

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    ZStack {
      theme.systemBackgroundColor
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Button {
            onCancel()
          } label: {
            Image(systemName: "xmark")
              .accessibilityLabel("cancel_button".localized)
              .bpFont(.title)
              .foregroundColor(theme.primaryColor)
              .frame(width: 44, height: 44)
              .background(
                Circle().stroke(theme.systemBackgroundColor.opacity(0.3), lineWidth: 1)
              )
          }

          Spacer()

          Button {
            onConfirm()
          } label: {
            Image(systemName: "checkmark")
              .accessibilityLabel("import_button".localized)
              .bpFont(.title)
              .foregroundColor(theme.primaryColor)
              .frame(width: 44, height: 44)
              .background(
                Circle().stroke(theme.systemBackgroundColor.opacity(0.3), lineWidth: 1)
              )
          }
          // Parity with the file flow's ImportViewController, which disables Done
          // at zero files: confirming an emptied list is a no-op — don't offer it
          .disabled(rows.isEmpty)
        }
        .safeAreaPadding(.top)

        // Headers
        Text("import_title".localized)
          .bpFont(.titleStory)
          .fontWeight(.bold)
          .foregroundColor(theme.primaryColor)

        Text("import_warning_description".localized)
          .bpFont(.subheadline)
          .foregroundColor(theme.primaryColor.opacity(0.6))
          .lineSpacing(4)

        Text(String.localizedStringWithFormat("files_title".localized, rows.count))
          .bpFont(.headline)
          .foregroundColor(theme.primaryColor.opacity(0.6))
          .padding(.top, 10)

        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(rows) { row in
              HStack(spacing: 16) {
                Button {
                  withAnimation {
                    onRemove(row.id)
                  }
                } label: {
                  Image(systemName: "minus.circle.fill")
                    .accessibilityLabel("delete_button".localized)
                    .foregroundColor(.red)
                    .bpFont(.titleLarge)
                }

                Image(systemName: row.icon)
                  .foregroundColor(.pink)
                  .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                  Text(row.title)
                    .foregroundColor(theme.primaryColor)
                    .bpFont(.footnote)
                    .lineLimit(1)

                  if let subtitle = row.subtitle {
                    Text(subtitle)
                      .foregroundColor(theme.secondaryColor)
                      .bpFont(.caption)
                      .lineLimit(1)
                  }
                }

                Spacer()
              }
              .padding(.vertical, 14)

              // Separator
              Divider()
                .background(theme.systemBackgroundColor.opacity(0.2))
            }
          }
        }

        Spacer()
      }
      .padding(.horizontal, 24)
    }
  }
}
