//
//  JellyfinConnectionView.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-25.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct JellyfinConnectionView: View {
  var viewModel: JellyfinConnectionViewModel
  /// Theme view model to update colors
  @StateObject var themeViewModel = ThemeViewModel()

  var body: some View {
    if #available(iOS 16.0, *) {
      JellyfinConnectionForm(viewModel: viewModel.formViewModel)
        .scrollContentBackground(.hidden)
    } else {
      JellyfinConnectionForm(viewModel: viewModel.formViewModel)
    }
  }
}

#Preview {
  JellyfinConnectionView(viewModel: JellyfinConnectionViewModel())
}
