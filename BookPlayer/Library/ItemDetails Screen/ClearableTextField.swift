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

  public var keyboardType: UIKeyboardType = .default
  public var textContentType: UITextContentType? = nil
  public var autocapitalization: UITextAutocapitalizationType = .sentences

  /// Current theme
  @EnvironmentObject var themeViewModel: ThemeViewModel

  init(_ placeholder: String, text: Binding<String>, configure: ((inout ClearableTextField) -> ())? = nil) {
    self.placeholder = placeholder
    _text = text
    configure?(&self)
  }

  var body: some View {
    HStack {
      TextField(placeholder, text: $text)
        .foregroundColor(themeViewModel.primaryColor)
        .keyboardType(keyboardType)
        .textContentType(textContentType)
        .autocapitalization(autocapitalization)
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
