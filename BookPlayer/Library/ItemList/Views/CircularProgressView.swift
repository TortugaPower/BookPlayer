//
//  CircularProgressView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct CircularProgressView: View {
  let progress: Double
  let isHighlighted: Bool
  /// A list row's size by default; larger over a tile's cover
  var length: CGFloat = 18

  @EnvironmentObject private var theme: ThemeViewModel

  var outlineColor: Color {
    if isHighlighted {
      theme.systemFillColor
    } else {
      theme.secondarySystemFillColor
    }
  }

  var body: some View {
    ZStack {
      if progress == 0 {
        EmptyView()
      } else if progress == 1 {
        Circle()
          .fill(theme.linkColor)
        Image(.completionIndicatorDone)
          .foregroundStyle(Color.white)
      } else {
        Circle()
          .stroke(lineWidth: 1.5)
          .foregroundStyle(outlineColor)
        Circle()
          .fill(theme.tertiarySystemBackgroundColor)
          .padding(2)
        PieSliceShape(progress: progress)
          .fill(outlineColor)
          .padding(2)
      }
    }
    .frame(width: length, height: length)
  }
}

#Preview {
  CircularProgressView(
    progress: 0.5,
    isHighlighted: true
  )
  .environmentObject(ThemeViewModel())
}

struct PieSliceShape: Shape {
  var progress: Double  // 0.0 to 1.0

  func path(in rect: CGRect) -> Path {
    var path = Path()

    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = min(rect.width, rect.height) / 2
    let startAngle = -90.0
    let endAngle = startAngle + (progress * 360)

    path.move(to: center)
    path.addArc(
      center: center,
      radius: radius,
      startAngle: .degrees(startAngle),
      endAngle: .degrees(endAngle),
      clockwise: false
    )
    path.closeSubpath()

    return path
  }
}
