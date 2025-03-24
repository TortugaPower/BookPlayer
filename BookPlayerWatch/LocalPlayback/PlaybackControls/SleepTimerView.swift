//
//  SleepTimerView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 22/3/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct SleepTimerView: View {
  @AppStorage(Constants.UserDefaults.customSleepTimerDuration) var customDuration: Int = 60
  @State var showCustomPicker: Bool = false

  @Environment(\.dismiss) var dismiss

  var body: some View {
    List {
      Button {
        SleepTimer.shared.setTimer(.off)
        dismiss()
      } label: {
        Text("sleep_off_title".localized)
          .font(.caption)
      }

      Button {
        SleepTimer.shared.setTimer(.endOfChapter)
        dismiss()
      } label: {
        Text("sleep_chapter_option_title".localized)
          .font(.caption)
      }

      Button {
        showCustomPicker = true
      } label: {
        Text("sleeptimer_option_custom".localized)
          .font(.caption)
      }

      ForEach(SleepTimer.shared.intervals, id: \.self) { interval in
        Button {
          SleepTimer.shared.setTimer(.countdown(interval))
          dismiss()
        } label: {
          Text(
            String.localizedStringWithFormat("sleep_interval_title".localized, TimeParser.formatDuration(interval))
          )
          .font(.caption)
        }
      }
    }
    .navigationTitle(Text("player_sleep_title"))
    .navigationBarTitleDisplayMode(.inline)
    .environment(\.defaultMinListRowHeight, 40)
    .fullScreenCover(isPresented: $showCustomPicker) {
      CountDownPickerView(startingTime: .init(seconds: customDuration)) { time in
        customDuration = time.totalSeconds
        SleepTimer.shared.setTimer(.countdown(TimeInterval(customDuration)))
        showCustomPicker = false
        dismiss()
      }
    }
  }
}

#Preview {
  if #available(watchOS 9.0, *) {
    NavigationStack {
      SleepTimerView()
    }
  } else {
    SleepTimerView()
  }
}
