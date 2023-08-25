//
//  NowPlayingView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 19/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct NowPlayingView: View {
  @EnvironmentObject var contextManager: ContextManager
  
  var body: some View {
    VStack {
      NowPlayingTitleView(
        author: contextManager.applicationContext.currentItem?.author ?? "",
        title: contextManager.applicationContext.currentItem?.title ?? ""
      )
      
      Spacer()
      
      NowPlayingMediaControlsView()
        .environmentObject(contextManager)
      
      Spacer()
      
      NowPlayingPlaybackControlsView()
        .environmentObject(contextManager)
    }
    .fixedSize(horizontal: false, vertical: false)
    .ignoresSafeArea(edges: .bottom)
  }
}
