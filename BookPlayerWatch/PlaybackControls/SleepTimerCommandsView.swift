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
  @State var error: Error?

  @Environment(\.dismiss) var dismiss

  var body: some View {
    List {
      Button {
        do {
          try contextManager.handleSleepTimer(.off)
          dismiss()
        } catch {
          self.error = error
        }

      } label: {
        Text("sleep_off_title".localized)
          .font(.caption)
      }

      Button {
        do {
          try contextManager.handleSleepTimer(.endOfChapter)
          dismiss()
        } catch {
          self.error = error
        }
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
          do {
            try contextManager.handleSleepTimer(.countdown(interval))
            dismiss()
          } catch {
            self.error = error
          }
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
        do {
          customDuration = time.totalSeconds
          showCustomPicker = false
          try contextManager.handleSleepTimer(.countdown(TimeInterval(customDuration)))
          dismiss()
        } catch {
          self.error = error
        }
      }
    }
    .errorAlert(error: $error)
  }
}

#Preview {
  SleepTimerCommandsView()
    .environmentObject(ContextManager())
}
