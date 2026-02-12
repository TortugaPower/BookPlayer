//
//  ListeningProgressView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct ListeningProgressView: View {
  @Binding var progress: Double
  var remainigTime: String
  var currentTime: String
  var progressLabel: String
  var onSliderChange: ((Double) -> Void)?
  
  var body: some View {
    VStack(spacing: 12) {
      SlickSlider(
        value: $progress,
        range: 0...1,
        onEditingChanged: { editing in
            if !editing {
              onSliderChange?(progress)
            }
        }
      )
      
      HStack {
        Text(currentTime)
        Spacer()
        Text(progressLabel)
        Spacer()
        Text(remainigTime)
      }
      .font(.caption)
      .foregroundColor(.secondary)
    }
  }
}

#Preview {
  ListeningProgressView(progress: .constant(0.4), remainigTime: "02:12", currentTime: "00:45", progressLabel: "Chapter 1 of 12")
}
