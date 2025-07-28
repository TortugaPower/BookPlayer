//
//  StorySkipControlsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/6/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct StoryRewindControlView: View {
  var onSkip: () -> Void
  var onPause: () -> Void
  var onResume: () -> Void
  @State var touchDateReference: Date?

  var longPressSkip: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { _ in
        if touchDateReference == nil {
          touchDateReference = Date()
          onPause()
        }
      }
      .onEnded { _ in
        guard let touchDateReference else { return }

        let time = touchDateReference.distance(to: Date())

        defer {
          self.touchDateReference = nil
        }

        if time <= 0.3 {
          onSkip()
        }

        onResume()
      }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 0) {
      Rectangle()
        .foregroundStyle(.clear)
        .contentShape(Rectangle())
        .gesture(longPressSkip)
        .accessibilityAction {
          onSkip()
        }
        .accessibilityValue("Previous")

      Rectangle()
        .foregroundStyle(.clear)
        .accessibilityHidden(true)
    }
    .accessibilityElement(children: .contain)
  }
}

struct StoryForwardControlView: View {
  var onSkip: () -> Void
  var onPause: () -> Void
  var onResume: () -> Void
  @State var touchDateReference: Date?

  var longPressSkip: some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { _ in
        if touchDateReference == nil {
          touchDateReference = Date()
          onPause()
        }
      }
      .onEnded { _ in
        guard let touchDateReference else { return }

        let time = touchDateReference.distance(to: Date())

        defer {
          self.touchDateReference = nil
        }

        if time <= 0.3 {
          onSkip()
        }

        onResume()
      }
  }

  var body: some View {
    HStack(alignment: .center, spacing: 0) {
      Rectangle()
        .foregroundStyle(.clear)
        .accessibilityHidden(true)
      Rectangle()
        .foregroundStyle(.clear)
        .contentShape(Rectangle())
        .gesture(longPressSkip)
        .accessibilityAction {
          onSkip()
        }
        .accessibilityValue("Next")
    }
    .accessibilityElement(children: .contain)
  }
}

#Preview {
  Group {
    StoryRewindControlView(onSkip: {
      print("onSkip")
    }, onPause: {
      print("onPause")
    }, onResume: {
      print("onResume")
    })
    StoryForwardControlView(onSkip: {
      print("onSkip")
    }, onPause: {
      print("onPause")
    }, onResume: {
      print("onResume")
    })
  }
}
