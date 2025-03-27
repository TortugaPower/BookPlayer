//
//  SleepTimerCommandsView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 25/3/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct SleepTimerCommandsView: View {
  @EnvironmentObject var contextManager: ContextManager
  @AppStorage(Constants.UserDefaults.customSleepTimerDuration) var customDuration: Int = 60
  @State var showCustomPicker: Bool = false

  @Environment(\.dismiss) var dismiss

  var body: some View {
    List {
      Button {
        contextManager.handleSleepTimer(.off)
        dismiss()
      } label: {
        Text("sleep_off_title".localized)
          .font(.caption)
      }

      Button {
        contextManager.handleSleepTimer(.endOfChapter)
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
          contextManager.handleSleepTimer(.countdown(interval))
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
        contextManager.handleSleepTimer(.countdown(TimeInterval(customDuration)))
        showCustomPicker = false
        dismiss()
      }
    }
  }
}

#Preview {
  SleepTimerCommandsView()
    .environmentObject(ContextManager())
}
