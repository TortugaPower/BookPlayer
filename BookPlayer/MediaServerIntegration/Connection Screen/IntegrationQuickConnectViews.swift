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
/// `alternativeSignIn == .quickConnect`.
struct IntegrationQuickConnectSectionView: View {
  /// Tapped when the user wants to begin the flow. The caller drives the actual
  /// `viewModel.handleStartAlternativeSignIn()` call so loading-state plumbing stays in one place.
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
        // Without this the stack hugs its widest child, so a short state like `.retrievingCode`
        // lays out a narrow column instead of a centred full-width one.
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.top, Self.topPadding)
      }
      // House list styling, same as every other themed scroll surface in the app. Beyond the background
      // it carries `toolbarColorScheme`, without which the navigation bar keeps the system colour scheme
      // instead of the theme's — a mismatched band above content that reads as a second background.
      .applyListStyle(with: theme, background: theme.systemBackgroundColor)
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
          .bpFont(.body)
          .foregroundStyle(theme.secondaryColor)
      }

    case .awaitingCode:
      Text("integration_quick_connect_awaiting_message".localized)
        .bpFont(.body)
        .multilineTextAlignment(.center)
        .foregroundStyle(theme.primaryColor)

    case .authenticating:
      VStack(spacing: Self.headerSpacing) {
        ProgressView()
          .controlSize(.large)
        Text("integration_quick_connect_authenticating_message".localized)
          .bpFont(.body)
          .foregroundStyle(theme.secondaryColor)
      }

    case .failed(let message):
      VStack(spacing: Self.headerSpacing) {
        Image(systemName: "exclamationmark.triangle")
          .font(.largeTitle.weight(.semibold))
          .foregroundStyle(theme.errorColor)
          .accessibilityHidden(true)
        Text(message)
          .bpFont(.body)
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
        // Deliberately not `bpFont`: `BPFont` has no monospaced case, and a monospaced digit is what
        // makes a transcribed code unambiguous (0/O, 1/l). Don't "fix" this to match the text around it.
        .font(.system(.largeTitle, design: .monospaced).weight(.semibold))
        .minimumScaleFactor(0.5)
        .tracking(Self.codeLetterSpacing)
        .foregroundStyle(theme.primaryColor)
        .padding(.vertical, Self.codePaddingVertical)
        .frame(maxWidth: .infinity)
        .background(theme.tertiarySystemBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: Self.codeCornerRadius))
        // Long-press to copy. Quick Connect's own convention is to offer nothing here — the reference
        // clients render a bare, inert code — on the reasoning that the code is typed on a *different*
        // device, so the clipboard can't reach it. That holds for a TV, but not for the common
        // self-hosted case where the authorizing session is a browser tab on this same phone.
        //
        // A context menu rather than `.textSelection(.enabled)`: text selection installs an edit-menu
        // interaction, which is enough for VoiceOver to announce "Actions available" while the edit
        // commands never appear in the Actions rotor — an announcement with nothing behind it. An
        // explicit action is both honest and actually reachable without a drag gesture.
        .contextMenu {
          Button {
            UIPasteboard.general.string = code
          } label: {
            Label("copy_button".localized, systemImage: "doc.on.doc")
          }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("integration_quick_connect_code_label".localized))
        .accessibilityValue(Text(code.map { String($0) }.joined(separator: " ")))
        // Restated explicitly: `.accessibilityElement(children: .ignore)` above drops the context
        // menu's own action along with the rest of the children.
        .accessibilityAction(named: Text("copy_button".localized)) {
          UIPasteboard.general.string = code
        }
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

        instructionRow(number: 1, attributed: openInstruction)
        instructionRow(number: 2, text: "jellyfin_quick_connect_instruction_sign_in".localized)
        instructionRow(number: 3, text: "jellyfin_quick_connect_instruction_open_menu".localized)
        instructionRow(number: 4, text: "integration_quick_connect_instruction_enter_code".localized)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  /// Step 1's sentence with the server URL turned into a tappable link.
  ///
  /// Deliberately built by attributing the *formatted* result rather than by splitting the string into
  /// "Open" + a separate link view: every locale keeps its own word order around `%@`, so this needs no
  /// translation work and can't strand a catalog holding a `%@` we no longer substitute. Languages that
  /// put the URL first, or wrap it in punctuation, keep working.
  ///
  /// A real link also beats text selection for this: tap opens the browser, long-press gives the
  /// system's Copy Link — scoped to the URL alone instead of the whole sentence.
  private var openInstruction: AttributedString {
    let formatted = String(
      format: "integration_quick_connect_instruction_open".localized,
      serverUrl
    )
    var attributed = AttributedString(formatted)
    // A URL the user typed may not parse, and a translation could in principle drop the placeholder —
    // in either case fall back to the plain sentence rather than showing nothing.
    //
    // The scheme check is the load-bearing part. `serverUrl` is user-typed and nothing in the Jellyfin
    // connection path constrains it — `createClient` does a bare `URL(string:)` — so without this a
    // `javascript:` or `file:` address would become a tappable link that SwiftUI hands to `openURL`.
    // Unreachable today, because a sheet only renders after `findServer` completed a real HTTP
    // round-trip that no such scheme could satisfy. That makes this defence-in-depth: it keeps the
    // guarantee local to the line that opens the URL rather than resting on a precondition three
    // screens away that a later refactor could quietly remove.
    guard
      let range = attributed.range(of: serverUrl),
      let url = URL(string: serverUrl),
      let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https"
    else { return attributed }
    attributed[range].link = url
    return attributed
  }

  /// One numbered step with no interactive content — steps 2 onward.
  ///
  /// Note what is *absent*: no `.accessibilityElement(children:)`. Both `.combine` and `.ignore` make
  /// SwiftUI synthesise a container element, and every row that announced a hollow "Actions available"
  /// had one. Hiding the number and folding it into the text's own label reaches the same single
  /// spoken result — "2. Sign in there" — without a synthesised container to hang an empty action
  /// list off.
  private func instructionRow(number: Int, text: String) -> some View {
    instructionRowLayout(number: number) {
      Text(text)
        .accessibilityLabel(Text("\(number). \(text)"))
    }
  }

  /// Step 1, whose sentence carries the server URL as a link.
  ///
  /// Deliberately unlabelled: overriding the label on a `Text` that carries an inline `.link` risks
  /// replacing the very content the link is attached to. The cost is that VoiceOver does not speak the
  /// step number on this row alone; the link staying reachable matters more.
  private func instructionRow(number: Int, attributed: AttributedString) -> some View {
    instructionRowLayout(number: number) {
      Text(attributed)
        .tint(theme.linkColor)
    }
  }

  /// Shared visual layout for a numbered step, so the two accessibility treatments above can't drift
  /// apart visually.
  private func instructionRowLayout<Content: View>(
    number: Int,
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(alignment: .top, spacing: Self.instructionRowSpacing) {
      Text("\(number).")
        .bpFont(.body)
        .foregroundStyle(theme.secondaryColor)
        // Folded into the text's label instead, so the row needs no accessibility container.
        .accessibilityHidden(true)
      content()
        .bpFont(.body)
        .foregroundStyle(theme.primaryColor)
        .fixedSize(horizontal: false, vertical: true)
    }
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
