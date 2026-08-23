//
//  PlayerState.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 31/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

@Observable
class PlayerState {
  var loadedBookRelativePath: String?
  var showPlayer = false
  var isShowingPlayer = false
  var showResumePopup = false
  var remotePlayTime: Double? = nil
  
  var showPlayerBinding: Binding<Bool> {
    .init(
      get: { self.showPlayer },
      set: { self.showPlayer = $0 }
    )
  }
  
  var isShowingPlayerBinding: Binding<Bool> {
    .init(
      get: { self.isShowingPlayer },
      set: { self.isShowingPlayer = $0 }
    )
  }
  
  /// The resume alert is attached in TWO places (MainView's base and the full-screen
  /// player's content): an alert beneath a presented fullScreenCover cannot present over
  /// it, and one inside the cover doesn't exist while the player is closed — the popup
  /// fires from EVERY playback start (mini-player, CarPlay, remote commands, restore),
  /// not just from the open player. Gating each copy on the cover's visibility ensures
  /// exactly one of them can present.
  func showResumePopupBinding(whenPlayerVisible visible: Bool) -> Binding<Bool> {
    .init(
      get: { self.showResumePopup && self.isShowingPlayer == visible },
      set: { self.showResumePopup = $0 }
    )
  }

  init() {}
}
