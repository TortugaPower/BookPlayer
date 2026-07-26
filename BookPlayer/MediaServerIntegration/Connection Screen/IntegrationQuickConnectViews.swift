//
//  IntegrationQuickConnectViews.swift
//  BookPlayer
//
//  Created by Matthew Alvernaz on 2026-04-27.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import UIKit

// MARK: - Section button

/// In-form section that lets the user start a Quick Connect flow as an alternative to
/// entering a username and password. Shown only in the `.foundServer` state of the shared
/// `IntegrationConnectionView` for integrations whose view model opts in via
/// `quickConnectSupported = true`.
struct IntegrationQuickConnectSectionView: View {
  /// Tapped when the user wants to begin the flow. The caller drives the actual
  /// `viewModel.handleStartQuickConnect()` call so loading-state plumbing stays in one place.
  var onStart: () -> Void

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    ThemedSection {
      Button(action: onStart) {
        Label(
          "integration_quick_connect_button".localized,
          systemImage: "key.horizontal"
        )
        .foregroundStyle(theme.linkColor)
      }
      .accessibilityHint(Text("integration_quick_connect_button_hint".localized))
    } header: {
      Text("integration_quick_connect_section_header".localized)
        .foregroundStyle(theme.secondaryColor)
    } footer: {
      Text("integration_quick_connect_section_footer".localized)
        .foregroundStyle(theme.secondaryColor)
    }
  }
}

// MARK: - Sheet

/// Modal sheet that walks the user through the Quick Connect flow once it has been started.
///
/// The sheet has three "happy path" rendering modes driven by `status`
/// (`.retrievingCode`, `.awaitingCode`, `.authenticating`) plus a `.failed` rendering for
/// terminal errors. The host view model owns the lifecycle; this view is a pure renderer
/// that calls `onCancel` for the user dismiss action and lets the host bind dismissal
/// from the outside (when status flips to `nil`).
struct IntegrationQuickConnectSheetView: View {
  /// Current state of the Quick Connect flow. The sheet's host pulls this from the view model
  /// and re-renders on changes; it never falls back to a default while the sheet is presented.
  let status: QuickConnectStatus

  /// The server URL the user is signing in to. Surfaced inside the instructions so the user
  /// knows which session to open in their browser when there are multiple Jellyfin tabs open.
  let serverUrl: String

  /// Tapped when the user wants to abort an in-flight flow or dismiss a failure. The host is
  /// responsible for actually clearing `quickConnectStatus`; this is just a notification.
  var onCancel: () -> Void

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: Self.contentSpacing) {
          headerView
          codeView
          instructionsView
        }
        .padding(.horizontal)
        .padding(.top, Self.topPadding)
      }
      .background(theme.systemBackgroundColor.ignoresSafeArea())
      .navigationTitle("integration_quick_connect_sheet_title".localized)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(closeButtonTitle, action: onCancel)
            .foregroundStyle(theme.linkColor)
        }
      }
      // This sheet swaps its whole content as the flow advances, and without an announcement a
      // VoiceOver user hears "Requesting a code…" and then silence — the code appears with no cue that
      // there is now something to read, and a terminal failure is equally silent.
      .onChange(of: status) { _, newStatus in
        announce(newStatus)
      }
    }
  }

  /// Speaks the state transition. The code is spelled out character by character: a short
  /// alphanumeric string read as a word is easily misheard, and the user has to retype it exactly.
  private func announce(_ status: QuickConnectStatus) {
    let message: String
    switch status {
    case .retrievingCode:
      message = "integration_quick_connect_retrieving_message".localized
    case .awaitingCode(let code):
      message = "\(("integration_quick_connect_awaiting_message").localized) \(code.map(String.init).joined(separator: " "))"
    case .authenticating:
      message = "integration_quick_connect_authenticating_message".localized
    case .failed(let reason):
      message = reason
    }
    UIAccessibility.post(notification: .announcement, argument: message)
  }

  // MARK: - Sub-views

  /// Status-dependent header — a progress spinner during retrieval/authentication, the
  /// "enter this code" prompt while polling, and an error icon on failure.
  @ViewBuilder
  private var headerView: some View {
    switch status {
    case .retrievingCode:
      VStack(spacing: Self.headerSpacing) {
        ProgressView()
          .controlSize(.large)
        Text("integration_quick_connect_retrieving_message".localized)
          .foregroundStyle(theme.secondaryColor)
      }

    case .awaitingCode:
      Text("integration_quick_connect_awaiting_message".localized)
        .multilineTextAlignment(.center)
        .foregroundStyle(theme.primaryColor)

    case .authenticating:
      VStack(spacing: Self.headerSpacing) {
        ProgressView()
          .controlSize(.large)
        Text("integration_quick_connect_authenticating_message".localized)
          .foregroundStyle(theme.secondaryColor)
      }

    case .failed(let message):
      VStack(spacing: Self.headerSpacing) {
        Image(systemName: "exclamationmark.triangle")
          .font(.largeTitle.weight(.semibold))
          .foregroundStyle(theme.errorColor)
          .accessibilityHidden(true)
        Text(message)
          .multilineTextAlignment(.center)
          .foregroundStyle(theme.primaryColor)
      }
    }
  }

  /// Renders the user-facing code in a large monospaced font so it's quick to read off the
  /// device. Hidden in non-`awaitingCode` states. The accessibility value is the code joined
  /// by spaces so VoiceOver reads it digit-by-digit instead of as one number.
  @ViewBuilder
  private var codeView: some View {
    if case .awaitingCode(let code) = status {
      Text(code)
        // Text-style-relative, not an absolute point size: this is the one element the sheet exists to
        // communicate, so it has to grow at accessibility text sizes. `minimumScaleFactor` keeps a
        // scaled-up code with `tracking` from clipping on a narrow screen.
        .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
        .minimumScaleFactor(0.5)
        .tracking(Self.codeLetterSpacing)
        .foregroundStyle(theme.primaryColor)
        .padding(.vertical, Self.codePaddingVertical)
        .frame(maxWidth: .infinity)
        .background(theme.tertiarySystemBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Self.codeCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("integration_quick_connect_code_label".localized))
        .accessibilityValue(Text(code.map { String($0) }.joined(separator: " ")))
    }
  }

  /// Step-by-step instructions, shown only while we have a code for the user to enter.
  @ViewBuilder
  private var instructionsView: some View {
    if case .awaitingCode = status {
      VStack(alignment: .leading, spacing: Self.instructionSpacing) {
        Text("integration_quick_connect_instructions_title".localized)
          .bpFont(.headline)
          .accessibilityAddTraits(.isHeader)
          .foregroundStyle(theme.primaryColor)

        instructionRow(
          number: 1,
          text: String(
            format: "integration_quick_connect_instruction_open".localized,
            serverUrl
          )
        )
        instructionRow(number: 2, text: "jellyfin_quick_connect_instruction_sign_in".localized)
        instructionRow(number: 3, text: "jellyfin_quick_connect_instruction_open_menu".localized)
        instructionRow(number: 4, text: "integration_quick_connect_instruction_enter_code".localized)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// One numbered step in the instructions list. Pulled out so VoiceOver reads each row as
  /// a single accessibility element ("step 1, ...") rather than splitting the number from
  /// the body text.
  private func instructionRow(number: Int, text: String) -> some View {
    HStack(alignment: .top, spacing: Self.instructionRowSpacing) {
      Text("\(number).")
        .bpFont(.body)
        .foregroundStyle(theme.secondaryColor)
      Text(text)
        .bpFont(.body)
        .foregroundStyle(theme.primaryColor)
        .fixedSize(horizontal: false, vertical: true)
    }
    .accessibilityElement(children: .combine)
  }

  /// "Cancel" while a flow is in progress; "OK" once it has terminally failed and the
  /// only outcome left is dismissal.
  private var closeButtonTitle: String {
    switch status {
    case .failed:
      return "ok_button".localized
    case .retrievingCode, .awaitingCode, .authenticating:
      return "cancel_button".localized
    }
  }

  // MARK: - Layout constants

  /// Top-level vertical padding inside the scroll view; keeps the spinner clear of the
  /// navigation bar without crowding the content.
  private static let topPadding: CGFloat = 24

  /// Vertical gap between the major content blocks (header, code, instructions).
  private static let contentSpacing: CGFloat = 24

  /// Vertical gap between a spinner and its label, or icon and its message in the header.
  private static let headerSpacing: CGFloat = 12

  /// Vertical gap between the instructions title and its rows / between rows.
  private static let instructionSpacing: CGFloat = 8

  /// Horizontal gap between the step number and the step text in an instruction row.
  private static let instructionRowSpacing: CGFloat = 8

  /// Inter-character tracking on the code; separates digits enough to scan but not so much
  /// that the block becomes wider than the sheet.
  private static let codeLetterSpacing: CGFloat = 4

  /// Vertical padding around the code "tile" so it has visible chrome.
  private static let codePaddingVertical: CGFloat = 24

  /// Corner radius of the code "tile". Matches the rest of the app's tile chrome.
  private static let codeCornerRadius: CGFloat = 12
}
