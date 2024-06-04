//
//  StoryActionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/6/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct StoryActionView: View {
  @Binding var action: StoryActionType
  @State private var selected: PricingOption
  @State private var showSlider = false
  @State private var sliderValue: Double
  private var sliderSelectedOption: PricingOption? {
    let intValue = Int(ceil(sliderValue))

    return PricingOption.parseValue(intValue)
  }
  var onSubscription: (PricingOption) -> Void
  var onDismiss: () -> Void

  init(
    action: Binding<StoryActionType>,
    onSubscription: @escaping (PricingOption) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self._action = action
    self.selected = action.wrappedValue.defaultOption
    self.sliderValue = action.wrappedValue.defaultOption.cost
    self.onSubscription = onSubscription
    self.onDismiss = onDismiss
  }

  var body: some View {
    VStack {
      if showSlider,
         let sliderOptions = action.sliderOptions {
        VStack {
          Text(String(format: "$%.0f/mo", sliderValue))
            .font(Font(Fonts.pricingTitle))
            .foregroundColor(.white)
            .accessibilityHidden(true)
          Slider(
            value: $sliderValue,
            in: sliderOptions.min...sliderOptions.max,
            step: 1.0
          ) {
            Text("Pay what you think is fair")
          } minimumValueLabel: {
            Text(String(format: "$%.0f", action.options.first!.cost))
              .font(Font(Fonts.title))
              .foregroundColor(.white)
              .accessibilityHidden(true)
          } maximumValueLabel: {
            Text(String(format: "$%.0f", action.options.last!.cost))
              .font(Font(Fonts.title))
              .foregroundColor(.white)
              .accessibilityHidden(true)
          }

          Text("Pay what you think is fair")
            .multilineTextAlignment(.center)
            .font(Font(Fonts.title))
            .foregroundColor(.white)
            .opacity(0.8)
            .accessibilityHidden(true)
        }
        .padding([.bottom], Spacing.L1)

      } else {
        HStack(spacing: Spacing.S1) {
          Spacer()
          ForEach(action.options) { option in
            PricingBoxView(
              title: .constant(option.title),
              isSelected: .constant(selected == option)
            )
            .onTapGesture {
              selected = option
            }
          }
          Spacer()
        }
        if action.sliderOptions != nil {
          Button(action: {
            showSlider.toggle()
          }, label: {
            Text("Choose custom amount")
              .font(Font(Fonts.title))
              .foregroundColor(.white)
              .underline()
              .padding([.top], Spacing.S4)
          })
        }
        }

      Button(action: {
        if showSlider,
            let option = sliderSelectedOption {
          onSubscription(option)
        } else {
          onSubscription(selected)
        }
      }, label: {
        Text(action.button)
          .contentShape(Rectangle())
          .font(Font(Fonts.headline))
          .frame(height: 45)
          .frame(maxWidth: .infinity)
          .foregroundColor(Color(UIColor(hex: "334046")))
          .background(Color.white)
          .cornerRadius(6)
      })
      .padding([.top], Spacing.L1)
      if let dismiss = action.dismiss {
        Button(action: {
          onDismiss()
        }, label: {
          Text(dismiss)
            .underline()
            .font(Font(Fonts.body))
            .foregroundColor(.white)
        })
        .padding([.top], Spacing.S5)
      }
    }
  }
}

#Preview {
  ZStack {
    StoryBackgroundView()
    StoryActionView(
      action: .constant(.init(
        options: [.supportTier4, .supportTier7, .supportTier10],
        defaultOption: .proMonthly,
        sliderOptions: .init(min: 3.99, max: 9.99),
        button: "Continue"
      )),
      onSubscription: { option in print(option.title) },
      onDismiss: {}
    )
  }
}
