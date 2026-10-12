//
//  MediaActionRow.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 26/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct MediaActionRow<TimerPopover: View>: View {
  let speedText: String
  let sleepText: String?
  let sleepAccessibilityLabel: String?

  @Binding var currentAlert: BPAlertContent?
  /// Shows `timerPopover` from the sleep timer button
  @Binding var showsTimerPopover: Bool

  let currentAlertOrigin: MediaAction?
  /// A fixed gap that keeps the buttons together in the middle; without one they spread
  /// evenly across the row
  var buttonSpacing: CGFloat? = nil
  let onActionTapped: (MediaAction) -> Void
  @ViewBuilder let timerPopover: () -> TimerPopover
    
  func iconImage(_ ma: MediaAction) -> Image? {
    switch ma {
    case .speed: return nil
    case .bookmark: return Image(.toolbarIconBookmark)
    case .timer: return Image(.toolbarIconTimer)
    case .more: return Image(.toolbarIconMore)
    default: return Image(systemName: ma.iconName)
    }
  }
  
  func labelText(_ ma: MediaAction) -> String? {
    return ma == .speed
      ? speedText
      : ma == .timer && sleepText != nil
        ? sleepText
        : nil
  }
  
  func accessibilityText(_ ma: MediaAction) -> String {
    return ma == .speed
      ? "\(speedText) \("speed_title".localized)"
      : ma.accessibilityLabel
  }

  func accessibilityValueText(_ ma: MediaAction) -> String? {
    switch ma {
    case .timer:
      return sleepAccessibilityLabel
    default:
      return nil
    }
  }
  
  var body: some View {
    HStack(spacing: buttonSpacing) {
      Spacer()
      ForEach(MediaAction.allCases) { ma in
        BubbleButton(
          iconImage: iconImage(ma),
          imageOffset: ma.iconOffset,
          labelText: labelText(ma),
          action: {
            onActionTapped(ma)
          }
        )
        .accessibilityLabel(accessibilityText(ma))
        .accessibilityValue(accessibilityValueText(ma) ?? "")
        .bpDialog(
          $currentAlert,
          isOriginView: currentAlertOrigin == ma
        )
        .popover(
          isPresented: ma == .timer ? $showsTimerPopover : .constant(false),
          content: timerPopover
        )

        if buttonSpacing == nil {
          Spacer()
        }
      }

      if buttonSpacing != nil {
        Spacer()
      }
    }
  }
}

#Preview {
  MediaActionRow(speedText: "2x", sleepText: nil, sleepAccessibilityLabel: nil, currentAlert: .constant(nil), showsTimerPopover: .constant(false), currentAlertOrigin: .timer, onActionTapped: { ma in print(ma.iconName) }) {
    EmptyView()
  }
}
