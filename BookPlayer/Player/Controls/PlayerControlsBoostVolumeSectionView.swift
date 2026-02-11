//
//  PlayerControlsBoostVolumeSectionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/10/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PlayerControlsBoostVolumeSectionView: View {
  @Binding var boostVolumeEnabled: Bool

  @EnvironmentObject private var theme: ThemeViewModel

  var body: some View {
    VStack(alignment: .leading, spacing: Spacing.S) {
      Toggle("settings_boostvolume_title", isOn: $boostVolumeEnabled)
        .bpFont(.subheadline)
        .bold()
        .foregroundStyle(theme.primaryColor)
        .tint(theme.linkColor)
        .accessibilityHint("settings_boostvolume_description")

      Text("settings_boostvolume_description")
        .bpFont(.caption)
        .foregroundStyle(theme.secondaryColor)
        .fixedSize(horizontal: false, vertical: true)
        .frame(minWidth: 160, alignment: .leading)
        .accessibilityHidden(true)
    }
  }
}

#Preview {
  @Previewable @State var boostVolumeEnabled: Bool = true
  PlayerControlsBoostVolumeSectionView(boostVolumeEnabled: $boostVolumeEnabled)
}
