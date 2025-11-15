//
//  AudiobookShelfSettingsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/14/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct AudiobookShelfSettingsView: View {
  @StateObject var viewModel: AudiobookShelfConnectionViewModel

  var body: some View {
    AudiobookShelfConnectionView(viewModel: viewModel)
      .navigationBarTitleDisplayMode(.inline)
  }
}
