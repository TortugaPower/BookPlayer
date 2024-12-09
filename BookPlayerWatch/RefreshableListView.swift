//
//  RefreshableListView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 2/12/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

/// Pull to refresh does not work natively on WatchOS
/// This implementation is inspired from this code:
/// https://gist.github.com/swiftui-lab/3de557a513fbdb2d8fced41e40347e01
struct RefreshableListView<Content: View>: View {
  @State private var previousScrollOffset: CGFloat = 0
  @State private var scrollOffset: CGFloat = 0
  @State private var rotation: Angle = .degrees(0)
  @Binding var refreshing: Bool

  let threshold: CGFloat = 40
  let content: Content

  init(refreshing: Binding<Bool>, @ViewBuilder content: () -> Content) {
    self._refreshing = refreshing
    self.content = content()
  }

  var body: some View {
    List {
      Section {
        if refreshing {
          ProgressView()
            .tint(.white)
            .frame(height: 10)
            .listRowBackground(Color.clear)
        } else {
          ZStack {
            MovingView()
            HStack {
              Spacer()
              Image(systemName: "arrow.down")
                .rotationEffect(rotation)
              Spacer()
            }
          }
          .listRowBackground(Color.clear)
        }
      }
      content
    }
    .customListSectionSpacing(0)
    .environment(\.defaultMinListRowHeight, 1)
    .background(FixedView())
    .onPreferenceChange(RefreshableKeyTypes.PrefKey.self) { values in
      refreshLogic(values: values)
    }
  }

  @MainActor
  func refreshLogic(values: [RefreshableKeyTypes.PrefData]) {
    // Calculate scroll offset
    let movingBounds = values.first { $0.vType == .movingView }?.bounds ?? .zero
    let fixedBounds = values.first { $0.vType == .fixedView }?.bounds ?? .zero

    self.scrollOffset = movingBounds.minY - fixedBounds.minY
    self.rotation = self.symbolRotation(self.scrollOffset)

    // Crossing the threshold on the way down, we start the refresh process
    if !self.refreshing && (self.scrollOffset > self.threshold && self.previousScrollOffset <= self.threshold) {
      self.refreshing = true
    }

    // Update last scroll offset
    self.previousScrollOffset = self.scrollOffset
  }

  func symbolRotation(_ scrollOffset: CGFloat) -> Angle {
    // We will begin rotation, only after we have passed
    // 60% of the way of reaching the threshold.
    if scrollOffset < self.threshold * 0.60 {
      return .degrees(0)
    } else {
      // Calculate rotation, based on the amount of scroll offset
      let h = Double(self.threshold)
      let d = Double(scrollOffset)
      let v = max(min(d - (h * 0.6), h * 0.4), 0)
      return .degrees(180 * v / (h * 0.4))
    }
  }

  struct MovingView: View {
    var body: some View {
      GeometryReader { proxy in
        Color.clear.preference(
          key: RefreshableKeyTypes.PrefKey.self,
          value: [RefreshableKeyTypes.PrefData(vType: .movingView, bounds: proxy.frame(in: .global))]
        )
      }.frame(height: 0)
    }
  }

  struct FixedView: View {
    var body: some View {
      GeometryReader { proxy in
        Color.clear.preference(
          key: RefreshableKeyTypes.PrefKey.self,
          value: [RefreshableKeyTypes.PrefData(vType: .fixedView, bounds: proxy.frame(in: .global))]
        )
      }
    }
  }
}

struct RefreshableKeyTypes {
  enum ViewType: Int {
    case movingView
    case fixedView
  }

  struct PrefData: Equatable {
    let vType: ViewType
    let bounds: CGRect
  }

  struct PrefKey: PreferenceKey {
    static var defaultValue: [PrefData] = []

    static func reduce(value: inout [PrefData], nextValue: () -> [PrefData]) {
      value.append(contentsOf: nextValue())
    }
  }
}
