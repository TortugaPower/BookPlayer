//
//  SystemVolumeSlider.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 22/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import MediaPlayer
import SwiftUI

struct SystemVolumeSlider: UIViewRepresentable {
  var tintColor: UIColor

  func makeUIView(context: Context) -> MPVolumeView {
    let volumeView = MPVolumeView()
    volumeView.showsRouteButton = false
    volumeView.tintColor = tintColor
    return volumeView
  }

  func updateUIView(_ uiView: MPVolumeView, context: Context) {
    uiView.tintColor = tintColor
  }
}
