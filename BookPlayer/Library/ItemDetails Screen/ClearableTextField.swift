//
//  ClearableTextField.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/12/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ClearableTextField: View {
  /// Text for the placeholder
  var placeholder: String
  /// Input's text
  @Binding var text: String
  /// An action to perform when the user performs an action (for example, when the user presses the Return key) while the text field has focus.
  var onCommit: () -> Void

  /// Current theme
  @EnvironmentObject var themeViewModel: ThemeViewModel

  init(_ placeholder: String, text: Binding<String>, onCommit: @escaping () -> Void = {}) {
    self.placeholder = placeholder
    _text = text
    self.onCommit = onCommit
  }

  var body: some View {
    HStack {
      TextField(placeholder, text: $text, onCommit: onCommit)
        .foregroundColor(themeViewModel.primaryColor)
      Image(systemName: "clear.fill")
        .foregroundColor(themeViewModel.secondaryColor)
        .onTapGesture {
          text = ""
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityRemoveTraits(.isImage)
    }
  }
}

struct ClearableTextField_Previews: PreviewProvider {
  static var previews: some View {
    ClearableTextField("Title", text: .constant(""))
      .environmentObject(ThemeViewModel())
  }
}
