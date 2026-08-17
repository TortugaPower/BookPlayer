//
//  ClearableTextField.swift
//  BookPlayer
//
//  Created by gianni.carlo on 18/12/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
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
        .foregroundStyle(themeViewModel.primaryColor)
      // Shown only when there is something to clear, like the system clear button — an X that clears
      // an empty field is a pointless VoiceOver stop.
      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(systemName: "clear.fill")
            .foregroundStyle(themeViewModel.secondaryColor)
        }
        // `.borderless`, because these fields sit in Form rows: a default-styled button there is
        // fired by the List's row-tap forwarding, so tapping anywhere in the row would clear the
        // text. A real Button (not the old tap gesture on the Image) is what gives VoiceOver proper
        // activation; the label is what it announces — the bare symbol read as its inferred name.
        .buttonStyle(.borderless)
        .accessibilityLabel(Text("clear_text_button".localized))
      }
    }
  }
}

struct ClearableTextField_Previews: PreviewProvider {
  static var previews: some View {
    ClearableTextField("Title", text: .constant(""))
      .environmentObject(ThemeViewModel())
  }
}
