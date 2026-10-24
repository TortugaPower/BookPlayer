//
//  DurationPickerPopover.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 12/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct NativeDurationPicker: View {
  @Binding var duration: TimeInterval
  
  // Computed properties to translate TimeInterval into hours and minutes
  private var hours: Int {
    Int(duration) / 3600
  }
  
  private var minutes: Int {
    (Int(duration) % 3600) / 60
  }
  
  var body: some View {
    HStack(spacing: 0) {
      // Hours Picker
      Picker("Hours".localized, selection: Binding(
        get: { self.hours },
        set: { newValue in updateDuration(newHours: newValue, newMinutes: self.minutes) }
      )) {
        ForEach(0..<24, id: \.self) { i in
          let text = Measurement(value: Double(i), unit: UnitDuration.hours)
            .formatted(.measurement(width: .wide))
          Text(text).tag(i)
        }
      }
      .pickerStyle(.wheel)
      .clipped()
      
      // Minutes Picker
      Picker("Minutes".localized, selection: Binding(
        get: { self.minutes },
        set: { newValue in updateDuration(newHours: self.hours, newMinutes: newValue) }
      )) {
        ForEach(0..<60, id: \.self) { i in
          let text = Measurement(value: Double(i), unit: UnitDuration.minutes)
            .formatted(.measurement(width: .abbreviated))
          Text(text).tag(i)
        }
      }
      .pickerStyle(.wheel)
      .clipped()
    }
  }
  
  private func updateDuration(newHours: Int, newMinutes: Int) {
    // Convert back to TimeInterval (seconds)
    duration = TimeInterval((newHours * 3600) + (newMinutes * 60))
  }
}

/// The custom sleep timer, shown as a popover from the player's sleep timer button. A popover sizes
/// itself to its content, so it grows with Dynamic Type instead of clipping, and on iPad and iPhone Duo
/// it stays next to the button rather than across the screen. Tapping outside cancels.
struct DurationPickerPopover: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject private var theme: ThemeViewModel

  var onConfirm: (TimeInterval) -> Void

  @State private var selectedDuration: TimeInterval

  init(initialDuration: TimeInterval, onConfirm: @escaping (TimeInterval) -> Void) {
    self.onConfirm = onConfirm
    /// Nothing is stored until a custom timer is set once (and the old sheet could store 0);
    /// start at an hour rather than at 0, where OK is disabled
    self._selectedDuration = State(initialValue: initialDuration > 0 ? initialDuration : 3600)
  }

  var body: some View {
    VStack(spacing: Spacing.S) {
      Text("sleeptimer_custom_alert_title".localized)
        .bpFont(.headline)
        .accessibilityAddTraits(.isHeader)

      NativeDurationPicker(duration: $selectedDuration)
        .frame(width: 300)
        /// Wheels are shorter in landscape; a fixed height would leave the gap below them
        .frame(maxHeight: 200)

      Button {
        onConfirm(selectedDuration)
        dismiss()
      } label: {
        Text("ok_button".localized)
          .fontWeight(.semibold)
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.glassProminent)
      .controlSize(.large)
      .tint(theme.linkColor)
      /// A zero-length countdown has nothing to time
      .disabled(selectedDuration == 0)
    }
    .padding(Spacing.S)
    /// Stays a popover on iPhone instead of turning into a sheet
    .presentationCompactAdaptation(.popover)
  }
}
