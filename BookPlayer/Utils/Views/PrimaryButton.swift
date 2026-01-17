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
    .buttonStyle(PrimaryButtonStyle(
      background: theme.useDarkVariant ? .white : .black,
      foregroundStyle: theme.useDarkVariant ? .black : .white
    ))
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  let background: Color
  let foregroundStyle: Color
  @Environment(\.isEnabled) var isEnabled

  func makeBody(configuration: Self.Configuration) -> some View {
    configuration.label
      .bpFont(Fonts.title)
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
      .clipShape(RoundedRectangle(cornerRadius: 24))
      .opacity(configuration.isPressed ? 0.4 : 1.0)
  }
}
