//
//  ImportConfirmationView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/9/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

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

/// The reusable import-confirmation shell: title, optional description, count, a
/// removable row list, and cancel/confirm actions. Deliberately presentation-agnostic —
/// dismissal, destructive-cancel semantics, and row sourcing belong to the flow
/// wrappers (see `ExternalImportView`).
///
/// # Gaps for the `ImportViewController` retirement
///
/// This shell is currently shaped for the external flow, whose needs are the simpler
/// half. Four things the UIKit screen does are NOT implemented here, and the file flow
/// cannot adopt it until they are. None of them are reachable today: an external batch
/// is frozen at confirmation and its removals cannot fail.
///
/// 1. **Failure has nowhere to go.** `onRemove` and `onCancel` are non-throwing, because the
///    external flow only mutates an array and dismisses. Their file-flow equivalents both
///    throw — `ImportViewModel.deleteItem` and `discardImportOperation` — and
///    `ImportViewController` catches each and raises `error_title`. Adopting needs throwing
///    closures, or an error binding, or those failures vanish silently. `onConfirm` is fine
///    as it is: `createOperation()` does not throw.
/// 2. **Folder rows.** `ImportViewController` picks `folder` vs `waveform` per item and
///    fills a "N Files" subtitle for folders. `ImportConfirmationRow` already carries
///    `icon` and `subtitle` for this; only the external flow's mapping ignores them,
///    since media-server items are always single files.
/// 3. **Live counts.** `ImportViewModel.subscribeNewFolders` runs a `DirectoryWatcher` per
///    nested SUBDIRECTORY — not the dropped folder itself, so files landing in its root
///    never bump `subItems` — and raises the count as files arrive. That is what
///    `import_warning_description` warns about, so without it the copy is a promise the
///    screen cannot keep, which is why the external flow passes no description at all.
/// 4. **Total vs row count.** The UIKit header counts files INSIDE folders via
///    `getTotalItems()`; this counts rows. Identical until folders appear.
struct ImportConfirmationView: View {
  let rows: [ImportConfirmationRow]
  /// Nil when the flow has no caveat to give. Not defaulted on purpose: a default is how
  /// the file flow's "transferring files may take a while" ended up on the external
  /// screen, where nothing transfers and the batch cannot change size.
  var description: LocalizedStringKey?
  let onRemove: (ImportConfirmationRow.ID) -> Void
  let onConfirm: () -> Void
  let onCancel: () -> Void

  @EnvironmentObject private var theme: ThemeViewModel

  /// Finder-style ordering, matching `ImportFileItem`'s `Comparable` and the library's own
  /// sort: "002" before "010", which plain string ordering gets wrong on the numbered
  /// filenames audiobooks almost always have. Sorted here rather than per flow so every
  /// adopter gets it.
  private var sortedRows: [ImportConfirmationRow] {
    rows.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
  }

  var body: some View {
    NavigationStack {
      List {
        Section {
          ForEach(sortedRows) { row in
            HStack(spacing: Spacing.S1) {
              Button {
                withAnimation {
                  onRemove(row.id)
                }
              } label: {
                Image(systemName: "minus.circle.fill")
                  .foregroundStyle(.red)
                  .bpFont(.titleLarge)
              }
              .buttonStyle(.plain)
              .accessibilityLabel("delete_button")

              Image(systemName: row.icon)
                .foregroundStyle(theme.linkColor)
                .accessibilityHidden(true)

              VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                  .foregroundStyle(theme.primaryColor)
                  .bpFont(.footnote)
                  .lineLimit(1)

                if let subtitle = row.subtitle {
                  Text(subtitle)
                    .foregroundStyle(theme.secondaryColor)
                    .bpFont(.caption)
                    .lineLimit(1)
                }
              }
            }
            .listRowBackground(theme.systemBackgroundColor)
          }
        } header: {
          Text(
            String.localizedStringWithFormat("files_title".localized, rows.count)
              .localizedCapitalized
          )
          .bpFont(.subheadline)
          .foregroundStyle(theme.secondaryColor)
          .accessibilityAddTraits(.isHeader)
        }
      }
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
      /// Pinned rather than a section footer: this is the caveat to read BEFORE confirming,
      /// and as a footer a long enough list scrolled it off screen entirely. `safeAreaInset`
      /// also reserves its height, so the last row can still be scrolled clear of it.
      .safeAreaInset(edge: .bottom) {
        if let description {
          Text(description)
            .bpFont(.subheadline)
            /// `primaryColor`, not secondary: on glass the muted tone loses too much
            /// contrast against whatever rows happen to scroll behind it.
            .foregroundStyle(theme.primaryColor)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.S)
            .padding(.vertical, Spacing.S1)
            /// An inset CARD, not a full-width capsule. `liquidGlassBackground` is built for
            /// floating, content-sized chrome — the mini player and the player's bubble
            /// buttons — so stretching it edge to edge produced a capsule with its ends
            /// clipped to the screen. Margins plus an explicit rounded rect give it the room
            /// the treatment expects.
            .glassCard()
            .padding(.horizontal, Spacing.S)
            .padding(.bottom, Spacing.S2)
        }
      }
      /// Set here rather than inherited: the two current call sites happen to sit under a
      /// `.tint(theme.linkColor)`, but a reusable shell should not depend on an ancestor the
      /// file flow will not have. `linkColor` also matches what UIKit puts on the bar —
      /// the hand-rolled buttons this replaced used `primaryColor`, which never did.
      .tint(theme.linkColor)
      /// Cancelling has to be a choice: a swipe-away would discard a staged import by
      /// accident. Deliberately STRICTER than the UIKit screen, which allows the swipe and
      /// runs `try? discardImportOperation()` from `presentationControllerDidDismiss` —
      /// cleanup whose failure it then swallows. The file flow should adopt this stricter
      /// behaviour rather than restore that path.
      .interactiveDismissDisabled()
      .navigationTitle("import_title")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            onCancel()
          } label: {
            Image(systemName: "xmark")
          }
          .accessibilityLabel("cancel_button")
        }

        ToolbarItem(placement: .confirmationAction) {
          Button {
            onConfirm()
          } label: {
            Image(systemName: "checkmark")
          }
          .accessibilityLabel("import_button")
          /// Parity with `ImportViewController`, which disables Done at zero files:
          /// confirming an emptied list is a no-op, so don't offer it.
          .disabled(rows.isEmpty)
        }
      }
    }
  }
}
