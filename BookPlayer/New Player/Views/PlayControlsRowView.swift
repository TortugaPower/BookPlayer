//
//  PlayControlsRow.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct PlayControlsRowView: View {
  var isPlaying: Bool
  @EnvironmentObject private var theme: ThemeViewModel
  @EnvironmentObject private var playerManager: PlayerManager
  
  var body: some View {
    HStack(spacing: 0) {
      Spacer()
      PlayerJumpView(backgroundImage: Image(systemName: "gobackward"), text: "-\(String(Int(PlayerManager.rewindInterval.rounded())))", tintColor: Color(theme.primaryColor)) {
        playerManager.rewind()
      }
      Spacer()
      Spacer()
      PlayerJumpView(backgroundImage: Image(systemName: isPlaying ? "pause.fill" : "play.fill"), text: "", tintColor: Color(theme.primaryColor)) {
        playerManager.playPause()
      }
      Spacer()
      Spacer()
      PlayerJumpView(backgroundImage: Image(systemName: "goforward"), text: "+\(String(Int(PlayerManager.forwardInterval.rounded())))", tintColor: Color(theme.primaryColor)) {
        playerManager.forward()
      }
      Spacer()
    }
    .frame(maxWidth: 400)
  }
}


#Preview {
  PlayControlsRowView(isPlaying: true)
}
