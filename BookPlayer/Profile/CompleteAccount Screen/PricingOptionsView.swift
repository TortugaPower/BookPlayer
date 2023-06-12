//
//  PricingOptionsView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 1/5/23.
//  Copyright © 2023 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct PricingOptionsView: View {
  @ObservedObject var viewModel: PricingViewModel
  @StateObject var themeViewModel = ThemeViewModel()

  var body: some View {
    VStack(spacing: Spacing.S1) {
      ForEach(viewModel.options) { option in
        PricingRowView(
          title: .constant(option.title),
          isSelected: .constant(viewModel.selected == option),
          isLoading: .constant(viewModel.isLoading)
        )
        .onTapGesture {
          viewModel.selected = option
        }
      }
    }
    .environmentObject(themeViewModel)
  }
}

struct PricingOptionsView_Previews: PreviewProvider {
  static var previews: some View {
    PricingOptionsView(
      viewModel: PricingViewModel(options: [
        PricingModel(id: "yearly", title: "$49.99 per year"),
        PricingModel(id: "monthly", title: "$4.99 per month")
      ])
    )
  }
}
