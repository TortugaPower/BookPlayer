//
//  LastPlayControlWidgetView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/10/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import AppIntents
import Foundation
import SwiftUI
import WidgetKit

struct PlayLastControlWidgetView: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(
      kind: "com.bookplayer.controlcenter.lastplayed"
    ) {
      ControlWidgetButton(action: LastBookStartPlaybackIntent()) {
        Label("intent_lastbook_play_title", systemImage: "play.circle")
      }
    }
    .displayName("intent_lastbook_play_title")
  }
}
