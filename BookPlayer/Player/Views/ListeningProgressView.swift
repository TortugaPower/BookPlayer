//
//  ListeningProgressView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

struct ListeningProgressView: View {
  @EnvironmentObject private var theme: ThemeViewModel
  @Binding var progress: Double
  var remainingTime: String
  var remainingTimeAccessLabel: String = ""
  var currentTime: String
  var currentTimeAccessLabel: String = ""
  var progressLabel: String
  var onSliderChange: ((Double) -> Void)?
  var onProgresToggle: (() -> Void)?
  var onRemainingToggle: (() -> Void)?
  
  var body: some View {
    VStack(spacing: 8) {
      SlickSlider(
        value: $progress,
        range: 0...1,
        onEditingChanged: { editing in
          if !editing {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onSliderChange?(progress)
          }
        },
        accentColor: theme.linkColor
      )
      
      HStack {
        Text(currentTime)
          .bpFont(.miniPlayerTitle).monospacedDigit()
          .frame(width: 120, alignment: .leading)
          .accessibilityLabel(currentTimeAccessLabel)
        Spacer()
        Button {
          onProgresToggle?()
        } label: {
          Text(progressLabel)
            .lineLimit(1)
            .bpFont(.miniPlayerTitle)
        }
        Spacer()
        Button {
          onRemainingToggle?()
        } label: {
          Text(remainingTime)
            .bpFont(.miniPlayerTitle).monospacedDigit()
            .frame(width: 120, alignment: .trailing)
        }
        .accessibilityLabel(remainingTimeAccessLabel)
      }
      .bpFont(.caption)
      .foregroundColor(.secondary)
    }
  }
}

#Preview {
  ListeningProgressView(progress: .constant(0.4), remainingTime: "02:12", currentTime: "00:45", progressLabel: "Chapter 1 of 12")
}
