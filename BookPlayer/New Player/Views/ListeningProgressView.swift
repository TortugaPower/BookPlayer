//
//  ListeningProgressView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct ListeningProgressView: View {
  @StateObject private var theme = ThemeViewModel()
  @Binding var progress: Double
  var remainigTime: String
  var currentTime: String
  var progressLabel: String
  var onSliderChange: ((Double) -> Void)?
  var onProgresToggle: (() -> Void)?
  var onRemainingToggle: (() -> Void)?
  
  var body: some View {
    VStack(spacing: 12) {
      SlickSlider(
        value: $progress,
        range: 0...1,
        onEditingChanged: { editing in
          if !editing {
            onSliderChange?(progress)
          }
        },
        accentColor: theme.linkColor
      )
      
      HStack {
        Text(currentTime)
          .frame(width: 60, alignment: .leading)
        Spacer()
        Button {
          onProgresToggle?()
        } label: {
          Text(progressLabel)
        }
        Spacer()
        Button {
          onRemainingToggle?()
        } label: {
          Text(remainigTime)
            .frame(width: 60, alignment: .trailing)
        }
      }
      .font(.caption)
      .foregroundColor(.secondary)
    }
  }
}

#Preview {
  ListeningProgressView(progress: .constant(0.4), remainigTime: "02:12", currentTime: "00:45", progressLabel: "Chapter 1 of 12")
}
