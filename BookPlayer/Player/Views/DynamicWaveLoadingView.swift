//
//  DynamicWaveLoadingView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 29/4/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct DynamicWaveLoadingView: View {
  // Controls the fade in/out of the background and wave
  @State private var isPulsing = false
  
  // Stores the current random heights for the waveform bars
  @State private var waveHeights: [CGFloat] = [0.5, 0.5, 0.5, 0.5, 0.5]
  
  // Customization properties
  let animationDuration: TimeInterval = 0.8
  let barCount = 5
  
  var body: some View {
    ZStack {
      // 1. The Dimming Background
      Color.black
        .opacity(isPulsing ? 0.6 : 0.2) // Pulses between slightly dark and very dark
        .edgesIgnoringSafeArea(.all)
      
      // 2. The Sound Wave
      HStack(spacing: 4) {
        ForEach(0..<barCount, id: \.self) { index in
          Capsule()
            .fill(Color.white)
          // The height is a base of 40px, multiplied by our random percentages
            .frame(width: 4, height: 40 * waveHeights[index])
        }
      }
      .opacity(isPulsing ? 1.0 : 0.0) // Fades completely out
    }
    .task {
      do {
        // This loop runs continuously as long as the view exists
        while !Task.isCancelled {
          // Step 1: Generate new random heights while the wave is invisible
          waveHeights = (0..<barCount).map { _ in CGFloat.random(in: 0.2...1.0) }
          
          // Step 2: Fade Everything In
          withAnimation(.easeInOut(duration: animationDuration)) {
            isPulsing = true
          }
          
          // Wait for the fade-in to finish
          try await Task.sleep(nanoseconds: UInt64(animationDuration * 1_000_000_000))
          
          // Step 3: Fade Everything Out
          withAnimation(.easeInOut(duration: animationDuration)) {
            isPulsing = false
          }
          
          // Wait for the fade-out to finish before looping to change shapes
          try await Task.sleep(nanoseconds: UInt64(animationDuration * 1_000_000_000))
        }
      } catch {
        withAnimation(.easeInOut(duration: animationDuration)) {
          isPulsing = false
        }
      }
    }
  }
}
