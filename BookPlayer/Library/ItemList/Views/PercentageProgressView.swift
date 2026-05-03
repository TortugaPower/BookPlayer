//
//  PercentageProgressView.swift
//  BookPlayer
//
//  Numeric counterpart to `CircularProgressView`. Selected by `ItemProgressView`
//  when the user enables the "show progress as percentage" library option.
//

import BookPlayerKit
import SwiftUI

struct PercentageProgressView: View {
  let progress: Double
  let isHighlighted: Bool

  @EnvironmentObject private var theme: ThemeViewModel

  private var labelColor: Color {
    isHighlighted ? theme.linkColor : theme.secondaryColor
  }

  var body: some View {
    Group {
      if progress == 0 {
        EmptyView()
      } else if progress == 1 {
        // Match the wheel's "finished" affordance exactly so toggling the
        // option doesn't change how completed items read.
        ZStack {
          Circle()
            .fill(theme.linkColor)
          Image(.completionIndicatorDone)
            .foregroundStyle(Color.white)
        }
        .frame(width: 18, height: 18)
      } else {
        Text("\(Int((progress * 100).rounded()))%")
          .bpFont(.miniPlayerTitle)
          .monospacedDigit()
          .foregroundStyle(labelColor)
      }
    }
    .frame(minWidth: 18, alignment: .trailing)
  }
}

#Preview {
  VStack(spacing: 12) {
    PercentageProgressView(progress: 0, isHighlighted: false)
    PercentageProgressView(progress: 0.27, isHighlighted: false)
    PercentageProgressView(progress: 0.78, isHighlighted: true)
    PercentageProgressView(progress: 1, isHighlighted: false)
  }
  .environmentObject(ThemeViewModel())
}
