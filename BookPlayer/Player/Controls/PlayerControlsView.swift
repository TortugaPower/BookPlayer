//
//  PlayerControlsView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PlayerControlsView: View {
  @StateObject private var model: Self.Model
  @StateObject private var theme = ThemeViewModel()
  @Environment(\.dismiss) private var dismiss

  @State private var showingMoreControls = false

  init(initModel: @escaping () -> Self.Model) {
    self._model = .init(wrappedValue: initModel())
  }

  var body: some View {
    NavigationStack {
      VStack(spacing: Spacing.S) {
        PlayerControlsSpeedSectionView(
          currentSpeed: Binding(
            get: { model.currentSpeed },
            set: { newValue in
              let rounded = model.roundSpeedValue(newValue)
              model.handleSpeedChange(rounded)
            }
          ),
          handleSpeedChange: model.handleSpeedChange
        )

        // Separator
        Rectangle()
          .fill(theme.secondaryColor)
          .frame(height: 0.5)

        // Boost Volume Section
        PlayerControlsBoostVolumeSectionView(boostVolumeEnabled: Binding(
          get: { model.isBoostVolumeEnabled },
          set: { newValue in
            model.handleBoostVolumeToggle(newValue)
          }
        ))

        // More Button
        Button {
          showingMoreControls = true
        } label: {
          Text("more_title")
        }
        .tint(theme.linkColor)
        .padding(.top, Spacing.S3)

        Spacer()
      }
      .environmentObject(theme)
      .padding(.horizontal, Spacing.M)
      .padding(.vertical, Spacing.S)
      .background(theme.systemBackgroundColor)
      .navigationTitle("settings_controls_title")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("done_title") {
            dismiss()
          }
          .foregroundStyle(theme.linkColor)
        }
      }
      .sheet(isPresented: $showingMoreControls) {
        NavigationStack {
          SettingsPlayerControlsView()
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button {
                  showingMoreControls.toggle()
                } label: {
                  Image(systemName: "xmark")
                    .foregroundStyle(theme.linkColor)
                }
              }
            }
        }
      }
    }
  }
}

// MARK: - Model

extension PlayerControlsView {
  class Model: ObservableObject {
    @Published var currentSpeed: Double = 1.0
    @Published var isBoostVolumeEnabled: Bool = false

    let speedStep: Double = 0.1

    init(
      currentSpeed: Double = 1.0,
      isBoostVolumeEnabled: Bool = false
    ) {
      self.currentSpeed = currentSpeed
      self.isBoostVolumeEnabled = isBoostVolumeEnabled
    }

    func roundSpeedValue(_ value: Double) -> Double {
      return round(value / speedStep) * speedStep
    }

    func handleSpeedChange(_ speed: Double) {}
    func handleBoostVolumeToggle(_ enabled: Bool) {}
  }
}

// MARK: - Preview

#Preview {
  PlayerControlsView {
    .init(
      currentSpeed: 1.5,
      isBoostVolumeEnabled: false
    )
  }
}
