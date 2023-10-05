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
  let options: [PricingModel]
  let isLoading: Bool
  @Binding var selected: PricingModel?

  var body: some View {
    VStack(spacing: Spacing.S1) {
      ForEach(options) { option in
        Button(action: isLoading ? {} : { selected = option },
               label: {
          PricingRowView(
            title: option.title,
            isSelected: selected == option,
            isLoading: isLoading)
        })
      }
    }
  }
}

struct PricingOptionsView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      PricingOptionsView(
        options: options,
        isLoading: false,
        selected: .constant(PricingModel(id: "yearly",
                                         title: "$49.99 per year")))
        .previewDisplayName("Stateless")

      OptionsViewWarper()
        .previewDisplayName("Stateful")
    }
    .padding()
    .environmentObject(ThemeViewModel())
  }

  static let options = [PricingModel(id: "yearly", title: "$49.99 per year"),
                        PricingModel(id: "monthly", title: "$4.99 per month")]

  private struct OptionsViewWarper: View {
    let options = PricingOptionsView_Previews.options

    @State var selectedOption: PricingModel?
    @State var isLoading = false

    var body: some View {
      VStack {
      PricingOptionsView(options: options,
                         isLoading: isLoading,
                         selected: $selectedOption)
        Toggle(isOn: $isLoading, label: {
          Text("Loading")
        })
      }
    }
  }
}

