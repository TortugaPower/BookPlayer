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
  /// The playback failure waiting to be shown, or nil. State rather than a presented alert so
  /// a failure raised while the app is backgrounded survives until the user comes back —
  /// the UIKit window walk this replaced simply found no key window and dropped it.
  var pendingFailure: PlaybackFailure?
  
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
  
  /// The failure alert is attached in TWO places (MainView's base and the full-screen
  /// player's content): an alert beneath a presented fullScreenCover cannot present over
  /// it, and one inside the cover doesn't exist while the player is closed — a failure can
  /// come from ANY playback start (mini-player, CarPlay, remote commands, restore), not just
  /// from the open player. Gating each copy on the cover's visibility ensures exactly one of
  /// them can present.
  func pendingFailureBinding(whenPlayerVisible visible: Bool) -> Binding<Bool> {
    .init(
      get: { self.pendingFailure != nil && self.isShowingPlayer == visible },
      set: { presented in
        if !presented {
          self.pendingFailure = nil
        }
      }
    )
  }

  /// Retires the pending failure. It belongs to the context that raised it and is NOT handed
  /// over when the player opens or closes — see the call site in `MainView` for why that is the
  /// deliberate choice rather than a workaround.
  func clearPrompts() {
    pendingFailure = nil
  }

  init() {}
}
