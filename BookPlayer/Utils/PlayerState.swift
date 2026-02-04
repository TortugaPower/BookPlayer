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
  var playerHeight: Float = 0

  var showPlayerBinding: Binding<Bool> {
    .init(
      get: { self.showPlayer },
      set: { self.showPlayer = $0 }
    )
  }
  
  var playerHeightBinding: Binding<Float> {
    .init(
      get: { self.playerHeight },
      set: { self.playerHeight = $0 }
    )
  }

  init() {}
}
