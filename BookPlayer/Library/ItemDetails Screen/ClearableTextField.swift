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
  /// Current theme
  @StateObject var themeViewModel = ThemeViewModel()

  init(_ placeholder: String, text: Binding<String>) {
    self.placeholder = placeholder
    _text = text
  }

  var body: some View {
    HStack {
      TextField(placeholder, text: $text)
        .foregroundColor(themeViewModel.primaryColor)
      Image(systemName: "xmark.circle.fill")
        .foregroundColor(themeViewModel.secondaryColor)
        .onTapGesture {
          text = ""
        }
    }
  }
}

struct ClearableTextField_Previews: PreviewProvider {
  static var previews: some View {
    ClearableTextField("Title", text: .constant(""))
  }
}
