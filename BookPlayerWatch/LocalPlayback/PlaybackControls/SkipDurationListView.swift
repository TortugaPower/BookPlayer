//
//  SkipDurationListView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 28/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct SkipDurationListView: View {
  @AppStorage(Constants.UserDefaults.rewindInterval) var selectedRewindInterval: TimeInterval = 30
  @AppStorage(Constants.UserDefaults.forwardInterval) var selectedForwardInterval: TimeInterval = 30
  @Environment(\.dismiss) var dismiss

  var skipDirection: SkipDirection

  var selectedInterval: TimeInterval {
    switch skipDirection {
    case .forward:
      selectedForwardInterval
    case .back:
      selectedRewindInterval
    }
  }

  private let intervals: [TimeInterval] = [
    2.0,
    5.0,
    10.0,
    15.0,
    20.0,
    30.0,
    45.0,
    60.0,
    90.0,
    120.0,
    180.0,
    240.0,
    300.0
  ]

  var body: some View {
    ScrollViewReader { proxy in
      List {
        ForEach(intervals, id: \.self) { interval in
          Button {
            switch skipDirection {
              case .forward:
              selectedForwardInterval = interval
            case .back:
              selectedRewindInterval = interval
            }
            dismiss()
          } label: {
            HStack {
              Text(TimeParser.formatDuration(interval))
                .font(.caption)
              Spacer()
              if interval == selectedInterval {
                Image(systemName: "checkmark")
                  .foregroundColor(.accentColor)
              }
            }
          }
        }
      }
      .onAppear {
        proxy.scrollTo(selectedInterval, anchor: .center)
      }
    }
  }
}

#Preview {
  SkipDurationListView(skipDirection: .forward)
}
