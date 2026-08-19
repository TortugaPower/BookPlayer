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

  /// VoiceOver label for the text field itself. Pass it here rather than applying
  /// `.accessibilityLabel` to this view from outside: this is a compound of two elements, and a
  /// label on the container propagates into the clear button too — which is exactly how the flow's
  /// clear button ended up announcing as "Host".
  var accessibilityLabel: String?

  /// Current theme
  @EnvironmentObject var themeViewModel: ThemeViewModel

  init(
    _ placeholder: String,
    text: Binding<String>,
    accessibilityLabel: String? = nil,
    onCommit: @escaping () -> Void = {}
  ) {
    self.placeholder = placeholder
    _text = text
    self.accessibilityLabel = accessibilityLabel
    self.onCommit = onCommit
  }

  var body: some View {
    HStack {
      TextField(placeholder, text: $text, onCommit: onCommit)
        .foregroundStyle(themeViewModel.primaryColor)
        .accessibilityLabel(Text(accessibilityLabel ?? placeholder))
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
        // activation.
        //
        // Deliberately NO explicit accessibility label: `clear.fill` ships with Apple's own localized
        // description ("Clear"), which is device-verified to announce correctly — and it only worked
        // wrong before because a label applied to the compound propagated in over it, which the
        // scoped `accessibilityLabel` parameter now makes impossible. Don't add a custom string here;
        // it would re-own 26 translations Apple already maintains.
        .buttonStyle(.borderless)
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
