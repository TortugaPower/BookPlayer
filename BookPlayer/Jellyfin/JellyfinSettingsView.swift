//
//  JellyfinSettingsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct JellyfinSettingsView: View {
  @StateObject var viewModel: JellyfinConnectionViewModel

  var body: some View {
    NavigationStack {
      JellyfinConnectionView(viewModel: viewModel)
        .navigationBarTitleDisplayMode(.inline)
    }
  }
}
