//
//  DurationPickerSheet.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 12/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct DurationPicker: UIViewRepresentable {
  @Binding var duration: TimeInterval
  
  func makeUIView(context: Context) -> UIDatePicker {
    let picker = UIDatePicker()
    picker.datePickerMode = .countDownTimer
    picker.addTarget(context.coordinator, action: #selector(Coordinator.updateDuration), for: .valueChanged)
    return picker
  }
  
  func updateUIView(_ uiView: UIDatePicker, context: Context) {
    uiView.countDownDuration = duration
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  class Coordinator: NSObject {
    let parent: DurationPicker
    init(_ parent: DurationPicker) { self.parent = parent }
    
    @objc func updateDuration(sender: UIDatePicker) {
      parent.duration = sender.countDownDuration
    }
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
      DurationPicker(duration: $selectedDuration)
        .frame(height: 200)
      
      VStack(spacing: 12) {
        Button {
          onConfirm(selectedDuration)
          dismiss()
        } label: {
          Text("OK")
            .fontWeight(.semibold)
            .frame(maxWidth: .infinity)
            .padding()
            .background(theme.systemGroupedBackgroundColor)
            .foregroundColor(theme.primaryColor)
            .cornerRadius(12)
        }
        
        Button("Cancel") {
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
