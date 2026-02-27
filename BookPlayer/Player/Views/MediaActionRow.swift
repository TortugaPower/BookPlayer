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

  @Binding var currentAlert: BPAlertContent?
  
  let currentAlertOrigin: MediaAction?
  let onActionTapped: (MediaAction) -> Void
    
  func iconImage(_ ma: MediaAction) -> Image? {
    return ma == .speed
      ? nil
      : ma == .bookmark
        ? Image(.toolbarIconBookmark)
        : Image(systemName: ma.iconName)
  }
  
  func labelText(_ ma: MediaAction) -> String? {
    return ma == .speed
      ? speedText
      : ma == .timer && sleepText != nil
        ? sleepText
        : nil
  }
  
  func accessibilityText(_ ma: MediaAction) -> String {
    return ma != .speed
      ? ma.accessibilityLabel
      : "\(speedText) \("speed_title".localized)"
  }
  
  var body: some View {
    HStack {
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
        .bpDialog(
          $currentAlert,
          isOriginView: currentAlertOrigin == ma
        )
        
        if ma != MediaAction.allCases.last {
          Spacer()
        }
      }
    }
  }
}

#Preview {
  MediaActionRow(speedText: "2x", sleepText: nil, currentAlert: .constant(nil), currentAlertOrigin: .timer, onActionTapped: { ma in print(ma.iconName) })
}
