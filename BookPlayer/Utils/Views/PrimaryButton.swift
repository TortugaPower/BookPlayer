//
//  PrimaryButton.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 17/1/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PrimaryButton: View {
  var text: String
  var action: () -> Void

  @EnvironmentObject var theme: ThemeViewModel

  var body: some View {
    Button(action: action, label: {
      Text(text)
    })
    /// The app's accent treatment, matching the Pro callout's Learn More button. It used to
    /// invert black/white by theme, which was an imitation of Sign in with Apple — and an
    /// unnecessary one: that button is Apple's own `SignInWithAppleButton` and gets its look
    /// from `.signInWithAppleButtonStyle`, never from here. The lookalike mostly turned up on
    /// sign-in screens standing next to the real thing.
    .buttonStyle(PrimaryButtonStyle(background: theme.linkColor, foregroundStyle: .white))
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  let background: Color
  let foregroundStyle: Color
  @Environment(\.isEnabled) var isEnabled

  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      /// `.headline` (17pt semibold), not `.title` (16pt callout): the smaller size left the
      /// label looking undersized in a 48pt button next to Sign in with Apple, whose text
      /// scales with its height. It is also the conventional size for a full-width iOS button.
      .bpFont(.headline)
      .frame(height: 48)
      .frame(maxWidth: .infinity)
      .background(
        isEnabled
        ? background
        : background.opacity(0.5)
      )
      .foregroundStyle(
        isEnabled
        ? foregroundStyle
        : foregroundStyle.opacity(0.5)
      )
      /// `Capsule`, not a hardcoded radius: it tracks the height instead of silently going
      /// wrong when someone changes it, and it matches the Pro callout's Learn More button.
      .clipShape(Capsule())
      .opacity(configuration.isPressed ? 0.4 : 1.0)
  }
}
