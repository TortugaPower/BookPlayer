//
//  ContainerNowPlayingView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 26/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import SwiftUI
import BookPlayerWatchKit

struct ContainerNowPlayingView: View {
  var item: PlayableItem?

  var body: some View {
    if let item = self.item {
      NowPlayingView(item: item)
    } else {
      EmptyNowPlayingView()
    }
  }
}

struct ContainerNowPlayingView_Previews: PreviewProvider {
  static var previews: some View {
    ContainerNowPlayingView()
  }
}
