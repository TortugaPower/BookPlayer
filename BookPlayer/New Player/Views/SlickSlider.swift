//
//  SlickSlider.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 12/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct SlickSlider: View {
  @Binding var value: Double
  var range: ClosedRange<Double> = 0...100
  
  // The callback closure, mimicking the native Slider API
  var onEditingChanged: (Bool) -> Void = { _ in }
  
  // Style settings
  private let trackHeight: CGFloat = 4
  private let thumbSize: CGFloat = 18
  private let accentColor = Color(red: 0.35, green: 0.6, blue: 0.9)
  
  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        // Background Track
        Capsule()
          .fill(Color.white.opacity(0.15))
          .frame(height: trackHeight)
        
        // Active Track
        Capsule()
          .fill(accentColor)
          .frame(width: max(0, CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width), height: trackHeight)
        
        // Thumb
        Circle()
          .fill(accentColor)
          .frame(width: thumbSize, height: thumbSize)
          .shadow(color: accentColor.opacity(0.6), radius: 6)
          .offset(x: CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width - (thumbSize / 2))
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { gesture in
                // 1. Signal that editing has started
                onEditingChanged(true)
                updateValue(with: gesture, in: geometry)
              }
              .onEnded { _ in
                // 2. Signal that editing has finished
                onEditingChanged(false)
              }
          )
      }
      .frame(height: thumbSize)
    }
    .frame(height: thumbSize)
  }
  
  private func updateValue(with gesture: DragGesture.Value, in geometry: GeometryProxy) {
    let newValue = Double(gesture.location.x / geometry.size.width) * (range.upperBound - range.lowerBound) + range.lowerBound
    self.value = min(max(range.lowerBound, newValue), range.upperBound)
  }
}

#Preview {
  SlickSlider(value: .constant(0.4))
}
