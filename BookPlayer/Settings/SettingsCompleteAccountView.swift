//
//  SettingsCompleteAccountView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import BookPlayerKit

struct SettingsCompleteAccountView: View {
  @Environment(\.dismiss) private var dismiss
  var subType: AccessLevel = .pro
  
  var body: some View {
    NavigationStack {
      CompleteAccountView(subType: subType) {
        dismiss()
      }
    }
  }
}

#Preview {
  SettingsCompleteAccountView()
}
