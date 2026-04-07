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
  
  var showResumePopupBinding: Binding<Bool> {
    .init(
      get: { self.showResumePopup },
      set: { self.showResumePopup = $0 }
    )
  }

  init() {}
}
