//
//  CountDownPickerView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 24/3/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct CountDownPickerView: View {
  @State var selectedHour = 0
  @State var selectedMinute = 1

  var completionHandler: (Time) -> Void

  /// VoiceOver helpers to avoid adding new strings for 'Hours' and 'Minutes'
  let hoursFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .spellOut
    formatter.allowedUnits = [.hour]
    formatter.collapsesLargestUnit = true
    return formatter
  }()
  let minutesFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .spellOut
    formatter.allowedUnits = [.minute]
    formatter.collapsesLargestUnit = true
    return formatter
  }()

  init(
    startingTime: Time,
    completionHandler: @escaping (Time) -> Void
  ) {
    self._selectedHour = .init(initialValue: startingTime.hour)
    self._selectedMinute = .init(initialValue: startingTime.minute)
    self.completionHandler = completionHandler
  }

  var body: some View {
    VStack {
      HStack {
        Picker("", selection: $selectedHour) {
          ForEach(0..<24, id: \.self) { hour in
            Text(String(format: "%02d", hour))
              .accessibilityLabel(Text(hoursFormatter.string(from: DateComponents(hour: hour)) ?? ""))
          }
        }
        Text(":")
          .accessibilityHidden(true)
        Picker("", selection: $selectedMinute) {
          ForEach(0..<60, id: \.self) { minute in
            Text(String(format: "%02d", minute))
              .accessibilityLabel(Text(minutesFormatter.string(from: DateComponents(minute: minute)) ?? ""))
          }
        }
      }
      Button("done_title".localized) {
        completionHandler(Time(hour: selectedHour, minute: selectedMinute))
      }
    }
  }
}

struct Time: Equatable {
  var hour: Int
  var minute: Int
  var second: Int = 0

  var totalSeconds: Int {
    return hour * 3600 + minute * 60 + second
  }
}

extension Time {
  init(seconds: Int) {
    self.second = seconds % 60
    self.minute = (seconds / 60) % 60
    self.hour = seconds / 3600
  }
}

#Preview {
  CountDownPickerView(startingTime: .init(hour: 0, minute: 5)) { time in
    print(time.totalSeconds)
  }
}
