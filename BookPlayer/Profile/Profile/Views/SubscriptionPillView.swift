//
//  SubscriptionPillView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 10/4/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct SubscriptionPillView: View {
  let title: String
  let backgroundColor: Color
  let foregroundColor: Color
  
  var body: some View {
    HStack(spacing: 4) {
      Text(title)
        .bpFont(.caption)
    }
    // The padding here dictates the thickness and width of the pill
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(backgroundColor)
    .foregroundColor(foregroundColor)
    // This is what makes it a perfect pill shape
    .clipShape(Capsule())
  }
}
