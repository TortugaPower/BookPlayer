//
//  MediaActionRow.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 26/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct MediaActionRow: View {
  let speedText: String
  let sleepText: String?
  let sleepAccessibilityLabel: String?

  @Binding var currentAlert: BPAlertContent?
  
  let currentAlertOrigin: MediaAction?
  let onActionTapped: (MediaAction) -> Void
    
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
    HStack {
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

        Spacer()
      }
    }
  }
}

#Preview {
  MediaActionRow(speedText: "2x", sleepText: nil, sleepAccessibilityLabel: nil, currentAlert: .constant(nil), currentAlertOrigin: .timer, onActionTapped: { ma in print(ma.iconName) })
}
