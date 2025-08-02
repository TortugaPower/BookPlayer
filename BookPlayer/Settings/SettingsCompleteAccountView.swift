//
//  SettingsCompleteAccountView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct SettingsCompleteAccountView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      CompleteAccountView {
        dismiss()
      }
    }
  }
}

#Preview {
  SettingsCompleteAccountView()
}
