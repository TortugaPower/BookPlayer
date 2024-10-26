//
//  JellyfinLibraryView.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct JellyfinLibraryView: View {
  var viewModel: JellyfinLibraryViewModel
  @StateObject var themeViewModel = ThemeViewModel()

  var body: some View {
    Text("Hello, World!")
  }
}

#Preview {
  JellyfinLibraryView(viewModel: JellyfinLibraryViewModel())
}
