//
//  PlaybackControlsView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 20/2/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct PlaybackControlsView: View {
  @EnvironmentObject var contextManager: ContextManager

  var body: some View {
    GeometryReader { metrics in
      List {
        Section("speed_title".localized.uppercased()) {
          VStack {
            HStack {
              Spacer()
              Button {
                contextManager.handleNewSpeed(contextManager.applicationContext.rate - 0.1)
              } label: {
                ResizeableImageView(name: "minus.circle")
              }
              .buttonStyle(PlainButtonStyle())
              .accessibilityLabel("➖")
              .frame(width: metrics.size.width * 0.15)
              Spacer()
                .padding([.leading], 5)
              Button {
                contextManager.handleNewSpeedJump()
              } label: {
                Text("\(contextManager.applicationContext.rate, specifier: "%.2f")x")
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
                contextManager.handleNewSpeed(contextManager.applicationContext.rate + 0.1)
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

        Section("settings_siri_sleeptimer_title".localized.uppercased()) {
          NavigationLink {
            SleepTimerCommandsView()
              .environmentObject(contextManager)
          } label: {
            HStack {
              Text("player_sleep_title".localized)
                .foregroundStyle(Color.primary)
              Spacer()
              Image(systemName: "chevron.forward")
            }
          }
        }

        Section("settings_playback_title".localized.uppercased()) {
          Toggle("settings_boostvolume_title", isOn: .init(
            get: { contextManager.applicationContext.boostVolume },
            set: { _ in
              contextManager.handleBoostVolumeToggle()
            }
          ))
        }
      }
    }
    .navigationTitle("settings_controls_title")
    .environment(\.defaultMinListRowHeight, 40)
  }
}

struct PlaybackControlsView_Previews: PreviewProvider {
  static var previews: some View {
    PlaybackControlsView()
      .environmentObject(ContextManager())
  }
}
