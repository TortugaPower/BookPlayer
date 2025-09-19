//
//  ButtonFreeView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI
import Combine

struct GestureConfig {
  var rewindSeconds: TimeInterval = 15
  var forwardSeconds: TimeInterval = 30
  var swipeThreshold: CGFloat = 32          // pts of movement to count as a swipe
  var edgeExclusion: CGFloat = 12           // ignore drags starting near edges (back gesture)
  var verticalOnlyCreatesBookmark = true    // vertical swipe = bookmark
}

struct ButtonFreeView: View {
  @StateObject var model: Self.Model
  @State private var message: String?
  @StateObject private var theme = ThemeViewModel()
  let config = GestureConfig()

  @Environment(\.dismiss) private var dismiss

  init(initModel: @escaping () -> Self.Model) {
    self._model = .init(wrappedValue: initModel())
  }

  var body: some View {
    NavigationStack {
      ZStack {
        theme.systemBackgroundColor
          .ignoresSafeArea()

        VStack(alignment: .leading, spacing: Spacing.S1) {
          Text("screen_gestures_title")
            .frame(maxWidth: .infinity, alignment: .leading)
            .bpFont(Fonts.title)
          Label("gesture_tap_title", systemImage: "hand.tap")
          Label("gesture_swipe_left_title", systemImage: "arrow.left")
          Label("gesture_swipe_right_title", systemImage: "arrow.right")
          Label("gesture_swipe_vertically_title", systemImage: "arrow.up.arrow.down")

          Spacer()
        }
        .padding(Spacing.M)
        .foregroundStyle(theme.primaryColor)
        .bpFont(Fonts.titleRegular)

        if let message {
          Text(message)
            .foregroundStyle(theme.primaryColor)
            .padding()
            .background(theme.systemGroupedBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
      }
      .gesture(
        ExclusiveGesture(
          TapGesture().onEnded {
            withAnimation {
              message = model.playPause()
            }
          },
          DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onEnded { value in handleDrag(value) }
        )
      )
      .onChange(of: message) {
        guard message != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          self.message = nil
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .navigationTitle("button_free_title")
      .navigationBarTitleDisplayMode(.inline)
      .accessibilityAction(.escape) {
        dismiss()
      }
      .onAppear {
        model.disableTimer(true)
      }
      .onDisappear {
        model.disableTimer(false)
      }
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "xmark")
              .foregroundStyle(theme.linkColor)
          }
        }
      }
    }
  }

  private func handleDrag(_ value: DragGesture.Value) {
    // Ignore drags that start too close to the screen edges to avoid fighting with
    // the navigation controller back-swipe and system gestures.
    if value.startLocation.x < config.edgeExclusion
      || value.startLocation.x > UIScreen.main.bounds.width - config.edgeExclusion
    {
      return
    }

    let tx = value.translation.width
    let ty = value.translation.height

    // Determine dominant axis
    if abs(tx) > abs(ty) {
      // Horizontal swipe
      if abs(tx) >= config.swipeThreshold {
        withAnimation {
          if tx < 0 {
            message = model.rewind()
          } else {
            message = model.forward()
          }
        }
      }
    } else {
      // Vertical swipe
      if abs(ty) >= config.swipeThreshold {
        withAnimation {
          message = model.createBookmark()
        }
      }
    }
  }
}

extension ButtonFreeView {
  class Model: ObservableObject {
    func playPause() -> String? { return "play" }
    func rewind() -> String? { return "rewind" }
    func forward() -> String? { return "forward" }
    func createBookmark() -> String? { return "bookmark" }
    func disableTimer(_ flag: Bool) {}
  }
}

#Preview {
  ButtonFreeView { .init() }
}
