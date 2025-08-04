//
//  PricingOptionsView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 1/5/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PricingOptionsView: View {
  @Binding var options: [PricingModel]
  @Binding var selected: PricingModel?
  @Binding var isLoading: Bool

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    VStack(spacing: Spacing.S1) {
      ForEach(options) { option in
        PricingRowView(
          title: option.title,
          isSelected: selected == option,
          isLoading: isLoading
        )
        .onTapGesture {
          selected = option
        }
      }
    }
  }
}
