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

  init() {}
}
