//
//  PlaybackFullControlsView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 25/11/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct PlaybackFullControlsView: View {
  @AppStorage(Constants.UserDefaults.globalSpeedEnabled) var globalSpeedEnabled: Bool = false
  @AppStorage(Constants.UserDefaults.boostVolumeEnabled) var boostVolumeEnabled: Bool = false
  @AppStorage(Constants.UserDefaults.autoplayEnabled) var autoplayEnabled: Bool = true
  @AppStorage(Constants.UserDefaults.rewindInterval) var rewindInterval: TimeInterval = 30
  @AppStorage(Constants.UserDefaults.forwardInterval) var forwardInterval: TimeInterval = 30
  @ObservedObject var model: PlaybackFullControlsViewModel
  @State var timerState: String = ""

  /// Formatter for the sleep timer state
  let timerStateFormatter: DateComponentsFormatter

  init(model: PlaybackFullControlsViewModel) {
    self.model = model
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .positional
    formatter.allowedUnits = [.minute, .second]
    formatter.collapsesLargestUnit = true
    self.timerStateFormatter = formatter
    self.updateTimerStateDescription(SleepTimer.shared.state)
  }

  func updateTimerStateDescription(_ state: SleepTimerState) {
    switch state {
    case .off:
      timerState = "player_sleep_title".localized
    case .endOfChapter:
      timerState = "sleep_alert_description".localized
    case .countdown(let seconds):
      let formattedTime = timerStateFormatter.string(from: seconds) ?? ""
      timerState = String.localizedStringWithFormat(
        "sleep_time_description".localized,
        formattedTime
      )
    }
  }

  var body: some View {
    GeometryReader { metrics in
      List {
        Section("speed_title".localized.uppercased()) {
          VStack {
            HStack {
              Spacer()
              Button {
                model.handleNewSpeed(model.rate - 0.1)
              } label: {
                ResizeableImageView(name: "minus.circle")
              }
              .buttonStyle(PlainButtonStyle())
              .accessibilityLabel("➖")
              .frame(width: metrics.size.width * 0.15)
              Spacer()
                .padding([.leading], 5)
              Button {
                model.handleNewSpeedJump()
              } label: {
                Text("\(model.rate, specifier: "%.2f")x")
                  .padding()
                  .frame(maxWidth: .infinity)
                  .background(Color.black.brightness(0.2))
                  .cornerRadius(5)
              }
              .buttonStyle(PlainButtonStyle())
              .frame(width: metrics.size.width * 0.4)

              Spacer()
                .padding([.leading], 5)
              Button {
                model.handleNewSpeed(model.rate + 0.1)
              } label: {
                ResizeableImageView(name: "plus.circle")
              }
              .buttonStyle(PlainButtonStyle())
              .accessibilityLabel("➕")
              .frame(width: metrics.size.width * 0.15)
              Spacer()
            }
          }
          .listRowBackground(Color.clear)

          Toggle(
            "settings_globalspeed_title",
            isOn: $globalSpeedEnabled
          )
        }

        Section("settings_siri_sleeptimer_title".localized.uppercased()) {
          NavigationLink {
            SleepTimerView()
          } label: {
            HStack {
              Text(timerState)
              Spacer()
              Image(systemName: "chevron.forward")
            }
          }
        }

        Section("settings_playback_title".localized.uppercased()) {
          Toggle(
            "settings_boostvolume_title",
            isOn: $boostVolumeEnabled
          )
          Toggle(
            "settings_autoplay_section_title".localized.capitalized,
            isOn: $autoplayEnabled
          )
        }

        Section("settings_skip_title") {
          NavigationLink {
            SkipDurationListView(skipDirection: .back)
          } label: {
            HStack {
              Text("settings_skip_rewind_title")
              Spacer()
              Text(TimeParser.formatDuration(rewindInterval))
              Image(systemName: "chevron.forward")
            }
          }

          NavigationLink {
            SkipDurationListView(skipDirection: .forward)
          } label: {
            HStack {
              Text("settings_skip_forward_title")
              Spacer()
              Text(TimeParser.formatDuration(forwardInterval))
              Image(systemName: "chevron.forward")
            }
          }
        }
      }
      .environment(\.defaultMinListRowHeight, 40)
      .onChange(of: boostVolumeEnabled) { boostVolume in
        model.handleBoostVolumeToggle(boostVolume)
      }
      .onReceive(SleepTimer.shared.$state) { state in
        updateTimerStateDescription(state)
      }
    }
    .navigationTitle("settings_controls_title")
  }
}
