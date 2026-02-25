//
//  DurationPickerSheet.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 12/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

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
            Picker("Hours", selection: Binding(
                get: { self.hours },
                set: { newValue in updateDuration(newHours: newValue, newMinutes: self.minutes) }
            )) {
                ForEach(0..<24, id: \.self) { i in
                    Text("\(i) hours").tag(i)
                }
            }
            .pickerStyle(.wheel)
            .clipped()
            
            // Minutes Picker
            Picker("Minutes", selection: Binding(
                get: { self.minutes },
                set: { newValue in updateDuration(newHours: self.hours, newMinutes: newValue) }
            )) {
                ForEach(0..<60, id: \.self) { i in
                    Text("\(i) min").tag(i)
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

struct DurationPickerSheet: View {
  @Environment(\.dismiss) var dismiss
  @EnvironmentObject private var theme: ThemeViewModel

  // The "handle" for the OK button
  var onConfirm: (TimeInterval) -> Void
  
  // Internal state for the picker
  @State private var selectedDuration: TimeInterval
  
  init(initialDuration: TimeInterval = 3600, onConfirm: @escaping (TimeInterval) -> Void) {
    self.onConfirm = onConfirm
    // Initialize state with the passed-in duration
    self._selectedDuration = State(initialValue: initialDuration)
  }
  
  var body: some View {
    VStack(spacing: 20) {
      Text("sleeptimer_custom_alert_title".localized)
        .bpFont(.headline)
        .padding(.top, 24)
      
      // Reusing the DurationPicker from the previous step
      NativeDurationPicker(duration: $selectedDuration)
        .frame(height: 200)
      
      VStack(spacing: 12) {
        Button {
          onConfirm(selectedDuration)
          dismiss()
        } label: {
          Text("ok_button".localized)
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(theme.systemGroupedBackgroundColor)
            .foregroundColor(theme.primaryColor)
            .cornerRadius(12)
        }
        
        Button("cancel_button".localized) {
          dismiss()
        }
        .foregroundColor(theme.primaryColor)
        .padding(.bottom, 10)
      }
      .padding(.horizontal, 20)
    }
    .presentationDetents([.height(400)]) // Fixed height for a neat look
    .presentationDragIndicator(.hidden)
  }
}
