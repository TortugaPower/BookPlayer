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
  @ObservedObject var model: PlaybackFullControlsViewModel
  @AppStorage(Constants.UserDefaults.globalSpeedEnabled) var globalSpeedEnabled: Bool = false
  @AppStorage(Constants.UserDefaults.boostVolumeEnabled) var boostVolumeEnabled: Bool = false
  @AppStorage(Constants.UserDefaults.autoplayEnabled) var autoplayEnabled: Bool = true
  @AppStorage(Constants.UserDefaults.rewindInterval) var rewindInterval: TimeInterval = 30
  @AppStorage(Constants.UserDefaults.forwardInterval) var forwardInterval: TimeInterval = 30

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
        }
        .listRowBackground(Color.clear)

        Section {
          Toggle(
            "settings_globalspeed_title",
            isOn: $globalSpeedEnabled
          )
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
    }
    .navigationTitle("settings_controls_title")
  }
}
