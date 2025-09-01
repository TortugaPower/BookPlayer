//
//  View+BookPlayer.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-11-10.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

extension View {
  @ViewBuilder
  func defaultFormBackground() -> some View {
    scrollContentBackground(.hidden)
  }
}

struct UIFontModifier: ViewModifier {
  let uiFont: UIFont

  func body(content: Content) -> some View {
    content.font(Font(uiFont))
  }
}

extension View {
  func bpFont(_ font: UIFont) -> some View {
    self.modifier(UIFontModifier(uiFont: font))
  }
}

extension View {
  func disabledWithOpacity(_ condition: Bool, opacity: Double = 0.5) -> some View {
    self
      .disabled(condition)
      .opacity(condition ? opacity : 1)
  }
}

struct MiniPlayerSafeAreaInsetModifier: ViewModifier {
  let spacing: CGFloat

  @Environment(\.playerState) var playerState

  func body(content: Content) -> some View {
    content
      .safeAreaInset(edge: .bottom) {
        Spacer().frame(
          height: playerState.loadedBookRelativePath != nil
            ? spacing
            : Spacing.M
        )
      }
  }
}

extension View {
  func miniPlayerSafeAreaInset(_ spacing: CGFloat = 112) -> some View {
    self.modifier(MiniPlayerSafeAreaInsetModifier(spacing: spacing))
  }
}

extension View {
  func applyListStyle(
    with theme: ThemeViewModel,
    background: Color
  ) -> some View {
    self
      .contentMargins(.top, Spacing.S1, for: .scrollContent)
      .scrollContentBackground(.hidden)
      .background(background)
      .toolbarColorScheme(theme.useDarkVariant ? .dark : .light, for: .navigationBar)
  }
}
