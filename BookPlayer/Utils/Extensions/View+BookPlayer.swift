//
//  View+BookPlayer.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-11-10.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

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
