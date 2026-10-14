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
  var onSliderDragChanged: ((Double) -> Void)? = nil
  var onSliderChange: ((Double) -> Void)?
  var onProgressToggle: (() -> Void)?
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
        onDragValueChanged: onSliderDragChanged,
        accentColor: theme.linkColor
      )
      .frame(height: 18)
      
      /// The times come first: each side takes the width of the longer one (the other is laid out
      /// hidden), so they stay on one line and the label between them stays centered. That label
      /// is the one that gives way when the row is short; only at the largest text sizes, when
      /// even the times don't fit, do they wrap
      HStack {
        ZStack(alignment: .leading) {
          Text(remainingTime)
            .hidden()
          Text(currentTime)
            .accessibilityLabel(currentTimeAccessLabel)
            .accessibilityIdentifier("player.currentTime")
        }
        .bpFont(.miniPlayerTitle).monospacedDigit()
        .layoutPriority(1)

        Button {
          onProgressToggle?()
        } label: {
          Text(progressLabel)
            .lineLimit(1)
            /// The end ("3 of 6") is the part worth keeping
            .truncationMode(.head)
            .bpFont(.miniPlayerTitle)
            .animation(nil, value: progressLabel)
        }
        .frame(maxWidth: .infinity)

        Button {
          onRemainingToggle?()
        } label: {
          ZStack(alignment: .trailing) {
            Text(currentTime)
              .hidden()
            Text(remainingTime)
          }
          .bpFont(.miniPlayerTitle).monospacedDigit()
        }
        .layoutPriority(1)
        .accessibilityLabel(remainingTimeAccessLabel)
      }
      .foregroundColor(.secondary)
    }
  }
}

#Preview {
  ListeningProgressView(progress: .constant(0.4), remainingTime: "02:12", currentTime: "00:45", progressLabel: "Chapter 1 of 12")
}
