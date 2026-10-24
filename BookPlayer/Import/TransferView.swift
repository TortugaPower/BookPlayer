//
//  TransferView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 17/10/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// The Transfer from Computer flow's sheet: the import shell, showing the address to open until the first
/// file arrives, then the files like any import. Done imports them, Cancel throws them away; like the import
/// screen, a swipe can't close it.
struct TransferView: View {
  /// Owns the session (initModel/@StateObject pattern): it lives exactly as long as the sheet.
  @StateObject private var model: TransferViewModel

  init(initModel: @escaping () -> TransferViewModel) {
    self._model = .init(wrappedValue: initModel())
  }

  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.dismiss) private var dismiss
  @State private var showsCopied = false
  /// Bumped by every Copy, so a second tap within the feedback's two seconds gets its own.
  @State private var copies = 0

  var body: some View {
    ImportConfirmationView(
      rows: model.rows,
      description: "transfer_footer",
      fileCount: model.fileCount,
      onRemove: { model.remove($0) },
      onConfirm: {
        model.confirm()
        dismiss()
      },
      onCancel: {
        model.discard()
        dismiss()
      }
    ) {
      emptyState
    }
    .onAppear {
      model.start()
    }
    .onDisappear {
      model.sheetDisappeared()
    }
    /// UIKit's notifications, not `scenePhase`: inside this sheet (the app hosts SwiftUI in a
    /// `UIHostingController`) `scenePhase` doesn't change when the app goes to the background.
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
      model.appEnteredBackground()
    }
    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
      model.appWillEnterForeground()
    }
  }

  // MARK: - Empty state

  @ViewBuilder
  private var emptyState: some View {
    switch model.status {
    case .starting:
      ProgressView()
    case .running:
      if let address = model.address {
        ContentUnavailableView {
          Label {
            Text("transfer_instructions")
              .foregroundStyle(theme.primaryColor)
          } icon: {
            Image(systemName: "laptopcomputer.and.arrow.down")
              .foregroundStyle(theme.secondaryColor)
          }
        } actions: {
          addressActions(address.url.absoluteString)
        }
      } else {
        ContentUnavailableView {
          Label("transfer_no_address", systemImage: "wifi.slash")
            .foregroundStyle(theme.primaryColor)
        }
      }
    }
  }

  @ViewBuilder
  private func addressActions(_ address: String) -> some View {
    Text(verbatim: address)
      .bpFont(.title2)
      .monospaced()
      .foregroundStyle(theme.primaryColor)
      .textSelection(.enabled)
      .accessibilityLabel("transfer_server_url_accessibility")
      .accessibilityValue(Text(verbatim: address))

    Button(
      showsCopied ? "transfer_server_copied_button" : "transfer_server_copy_button",
      systemImage: showsCopied ? "checkmark" : "doc.on.doc"
    ) {
      model.copyAddress()
      showsCopied = true
      copies += 1
      // The label's change isn't reliably spoken while the button has focus.
      UIAccessibility.post(notification: .announcement, argument: "transfer_server_copied_button".localized)
    }
    .bpFont(.body)
    // Spoken as Copy throughout: the announcement says it worked, and a label that changes under
    // VoiceOver's focus can be read again over it.
    .accessibilityLabel("transfer_server_copy_button")
    .contentTransition(.symbolEffect(.replace))
    .sensoryFeedback(.success, trigger: copies)
    .task(id: copies) {
      guard copies > 0 else { return }
      try? await Task.sleep(for: .seconds(2))
      // A newer tap cancels this one and starts its own two seconds.
      guard !Task.isCancelled else { return }
      showsCopied = false
    }
  }
}
