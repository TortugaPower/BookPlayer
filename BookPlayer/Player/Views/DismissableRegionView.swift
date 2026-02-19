//
//  DismissableRegionView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct DismissableRegionView: View {
  @Environment(\.dismiss) var dismiss

  var body: some View {
    HStack {
        Spacer()
        RoundedRectangle(cornerRadius: 3)
            .fill(Color.secondary.opacity(0.4))
            .frame(width: 60, height: 6)
            .padding(.vertical, 16)
        Spacer()
    }
    .contentShape(Rectangle())
    .frame(maxWidth: .infinity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("voiceover_dismiss_player_title".localized)
    .accessibilityAddTraits(.isButton)    
    .accessibilityAction {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        dismiss()
    }
  }
}

#Preview {
  DismissableRegionView()
}
