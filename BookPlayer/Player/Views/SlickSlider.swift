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
  var onDragValueChanged: ((Double) -> Void)? = nil
  
  @State private var localValue: Double = 0
  @State private var isDragging: Bool = false
  
  // Style settings
  private let trackHeight: CGFloat = 4
  private let thumbSize: CGFloat = 18
  var accentColor = Color(red: 0.35, green: 0.6, blue: 0.9)
  
  var body: some View {
    GeometryReader { geometry in
      let displayValue = min(max(isDragging ? localValue : value, range.lowerBound), range.upperBound)
      let horizontalBaseRatio = range.upperBound != range.lowerBound
        ? CGFloat((displayValue - range.lowerBound) / (range.upperBound - range.lowerBound))
        : 0.0
      
      ZStack(alignment: .leading) {
        // Background Track
        Capsule()
          .fill(Color.secondary.opacity(0.2))
          .frame(height: trackHeight)
        
        // Active Track
        Capsule()
          .fill(accentColor)
          .frame(width: max(0, horizontalBaseRatio * geometry.size.width), height: 4)
        
        // Thumb
        Circle()
          .fill(accentColor)
          .frame(width: thumbSize, height: thumbSize)
          .shadow(color: accentColor.opacity(0.6), radius: 6)
          .offset(x: horizontalBaseRatio * geometry.size.width - (thumbSize / 2))
          .highPriorityGesture(
            DragGesture(minimumDistance: 0)
              .onChanged { gesture in
                if !isDragging {
                  isDragging = true
                  onEditingChanged(true)
                }
                // Update only the local UI state
                updateLocalValue(with: gesture, in: geometry)
                onDragValueChanged?(localValue)
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
    .accessibilityElement(children: .combine)
    .accessibilityValue(getAccessibilityLabel(localValue))
    .accessibilityAdjustableAction { direction in
      isDragging = true
      onEditingChanged(true)
      
      let step = (range.upperBound - range.lowerBound) * 0.05 // 5% jumps
      var newTargetValue = localValue
      
      switch direction {
      case .increment:
        newTargetValue = min(localValue + step, range.upperBound)
      case .decrement:
        newTargetValue = max(localValue - step, range.lowerBound)
      @unknown default:
        break
      }
      
      localValue = newTargetValue
      onDragValueChanged?(localValue)
      value = newTargetValue
      
      onEditingChanged(false)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        isDragging = false
      }
    }
  }
  
  private func updateLocalValue(with gesture: DragGesture.Value, in geometry: GeometryProxy) {
      let percent = Double(gesture.location.x / geometry.size.width)
      let newValue = percent * (range.upperBound - range.lowerBound) + range.lowerBound
      self.localValue = min(max(range.lowerBound, newValue), range.upperBound)
  }
  
  private func getAccessibilityLabel(_ myValue: Double? = nil) -> String {
    let percentageValue = Int(((myValue ?? value) * 100 / (range.upperBound == 0 ? 1 : range.upperBound)).rounded(.up))
    return String.localizedStringWithFormat("progress_complete_description".localized, percentageValue)
  }
}

#Preview {
  SlickSlider(value: .constant(0.4))
}
