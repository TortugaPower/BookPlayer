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
  @Binding var options: [PricingModel]
  @Binding var selected: PricingModel?
  @Binding var isLoading: Bool
  var onSelected: ((PricingModel) -> Void)?

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
          onSelected?(option)
        }
      }
    }
  }
}

struct PricingOptionsView_Previews: PreviewProvider {
  static var previews: some View {
    PricingOptionsView(
      options: .constant([
        PricingModel(id: "yearly", title: "$49.99 per year"),
        PricingModel(id: "monthly", title: "$4.99 per month")
      ]),
      selected: .constant(PricingModel(id: "yearly", title: "$49.99 per year")),
      isLoading: .constant(false),
      onSelected: nil
    )
    .environmentObject(ThemeViewModel())
  }
}
