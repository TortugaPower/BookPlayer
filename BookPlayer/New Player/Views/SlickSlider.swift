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
  
  @State private var localValue: Double = 0
  @State private var isDragging: Bool = false
  
  // Style settings
  private let trackHeight: CGFloat = 4
  private let thumbSize: CGFloat = 18
  var accentColor = Color(red: 0.35, green: 0.6, blue: 0.9)
  
  var body: some View {
    GeometryReader { geometry in
      let displayValue = isDragging ? localValue : value
      
      ZStack(alignment: .leading) {
        // Background Track
        Capsule()
          .fill(Color.white.opacity(0.15))
          .frame(height: trackHeight)
        
        // Active Track
        Capsule()
          .fill(accentColor)
          .frame(width: max(0, CGFloat((displayValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width), height: 4)
        
        // Thumb
        Circle()
          .fill(accentColor)
          .frame(width: thumbSize, height: thumbSize)
          .shadow(color: accentColor.opacity(0.6), radius: 6)
          .offset(x: CGFloat((displayValue - range.lowerBound) / (range.upperBound - range.lowerBound)) * geometry.size.width - 9)
          .gesture(
            DragGesture(minimumDistance: 0)
              .onChanged { gesture in
                if !isDragging {
                  isDragging = true
                  onEditingChanged(true)
                }
                // Update only the local UI state
                updateLocalValue(with: gesture, in: geometry)
              }
              .onEnded { _ in
                // 3. Push the final local value back to the Binding (Singleton)
                value = localValue
                onEditingChanged(false)
                
                // Delay the unlock slightly to allow the Singleton to "catch up"
                // to the new seek position, preventing the 'jump-back'
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                  isDragging = false
                }
              }
          )
      }
      .frame(height: thumbSize)
    }
    .frame(height: thumbSize)
    .onAppear { localValue = value }
    .onChange(of: value) { _, newValue in
        if !isDragging {
            localValue = newValue
        }
    }
  }
  
  private func updateLocalValue(with gesture: DragGesture.Value, in geometry: GeometryProxy) {
      let percent = Double(gesture.location.x / geometry.size.width)
      let newValue = percent * (range.upperBound - range.lowerBound) + range.lowerBound
      self.localValue = min(max(range.lowerBound, newValue), range.upperBound)
  }
}

#Preview {
  SlickSlider(value: .constant(0.4))
}
