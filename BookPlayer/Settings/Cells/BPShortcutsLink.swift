//
//  BPShortcutsLink.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 22/10/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import _AppIntents_SwiftUI
import SwiftUI

@available(iOS 16.4, *)
struct BPShortcutsLink: View {
  /// Theme view model to update colors
  @StateObject var themeViewModel = ThemeViewModel()

  var body: some View {
    ShortcutsLink()
      .shortcutsLinkStyle(themeViewModel.useDarkVariant ? .dark : .light)
  }
}

@available(iOS 16.4, *)
#Preview {
  BPShortcutsLink()
}
