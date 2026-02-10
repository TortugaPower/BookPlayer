//
//  PlayControlsRow.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct PlayControlsRowView: View {
  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    HStack(spacing: 0) {
      Spacer()
      PlayerJumpView(backgroundImage: Image(systemName: "gobackward"), text: "-20", tintColor: Color(theme.primaryColor)) {
        print("pressed")
      }
      Spacer()
      PlayerJumpView(backgroundImage: Image(systemName: "play.fill"), text: "", tintColor: Color(theme.primaryColor)) {
        print("pressed")
      }
      Spacer()
      PlayerJumpView(backgroundImage: Image(systemName: "gobackward"), text: "-20", tintColor: Color(theme.primaryColor)) {
        print("pressed")
      }
      Spacer()
    }
    .frame(maxWidth: 400)
  }
}

#Preview {
    PlayControlsRowView()
}
