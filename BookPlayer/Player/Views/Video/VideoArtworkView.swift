//
//  VideoArtworkView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 15/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

/// Takes the artwork's place in the player screen when the current chapter is a video
struct VideoArtworkView: View {
  @EnvironmentObject private var playerManager: PlayerManager

  @State private var containerFrame: CGRect = .zero
  @State private var controlsVisible = true

  var body: some View {
    ZStack {
      // 1. Create the square "box"
      Color.clear
        .aspectRatio(1, contentMode: .fit)

      VideoPlayerSurface(player: playerManager.getAVPlayer(), hostsPictureInPicture: true)
        .contentShape(Rectangle())
        .onTapGesture {
          withAnimation(.easeInOut(duration: 0.2)) {
            controlsVisible.toggle()
          }
        }

      VStack {
        HStack(spacing: 12) {
          Spacer()

          Button {
            VideoFullscreenPresenter.present(playerManager: playerManager, from: containerFrame)
          } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(width: 20, height: 20)
              .foregroundColor(.white)
              .frame(width: 44, height: 44) // Standard touch target size
              .contentShape(Rectangle())
          }
          .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
          .accessibilityLabel(Text("video_fullscreen_title".localized))

          AirplayPicker()
            .frame(width: 44, height: 44) // Standard touch target size
            .padding(.trailing, 5)
            .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("audio_source_title"))
        }
        .padding(.top, 5)
        .frame(maxWidth: .infinity)

        Spacer()
      }
      .opacity(controlsVisible ? 1 : 0)
      .allowsHitTesting(controlsVisible)
      /// Keep VoiceOver from focusing the fullscreen/AirPlay buttons while they're
      /// hidden — `opacity(0)` alone leaves them in the accessibility tree
      .accessibilityHidden(!controlsVisible)
    }
    .aspectRatio(1, contentMode: .fit)
    .cornerRadius(12)
    .clipped()
    .background(
      GeometryReader { geometry in
        Color.clear
          .onAppear {
            containerFrame = geometry.frame(in: .global)
          }
          .onChange(of: geometry.frame(in: .global)) { _, newFrame in
            containerFrame = newFrame
          }
      }
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
