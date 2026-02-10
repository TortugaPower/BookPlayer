//
//  ListeningProgressView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct ListeningProgressView: View {
  var body: some View {
    VStack(spacing: 12) {
      ProgressView(value: 0.4)
        .progressViewStyle(.linear)
      
      HStack {
        Text("00:45")
        Spacer()
        Text("02:30")
        Spacer()
        Text("02:30")
      }
      .font(.caption)
      .foregroundColor(.secondary)
    }
  }
}

#Preview {
    ListeningProgressView()
}
