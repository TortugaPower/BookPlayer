//
//  StoryActionView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/6/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct StoryActionView: View {
  @Binding var action: StoryActionType
  @State private var selected: PricingModel
  @State private var showSlider = false
  @State private var sliderValue: Double
  private var sliderSelectedOption: PricingModel? {
    let intValue = Int(ceil(sliderValue))

    guard let option = PricingOption.parseValue(intValue) else {
      return nil
    }

    return PricingModel(
      id: option.rawValue,
      title: option.title,
      price: option.cost
    )
  }
  var onSubscription: (PricingModel) -> Void
  var onDismiss: () -> Void
  var onTipJar: (String?) -> Void

  init(
    action: Binding<StoryActionType>,
    onSubscription: @escaping (PricingModel) -> Void,
    onDismiss: @escaping () -> Void,
    onTipJar: @escaping (String?) -> Void
  ) {
    self._action = action
    self.selected = action.wrappedValue.defaultOption
    self.sliderValue = action.wrappedValue.defaultOption.price
    self.onSubscription = onSubscription
    self.onDismiss = onDismiss
    self.onTipJar = onTipJar
  }

  var body: some View {
    VStack {
      if showSlider,
        let sliderOptions = action.sliderOptions
      {
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
            Text(String(format: "$%.0f", action.options.first!.price))
              .font(Font(Fonts.title))
              .foregroundColor(.white)
              .accessibilityHidden(true)
          } maximumValueLabel: {
            Text(String(format: "$%.0f", action.options.last!.price))
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
        VStack {
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
            Button(
              action: {
                showSlider.toggle()
              },
              label: {
                Text("Choose custom amount")
                  .font(Font(Fonts.title))
                  .foregroundColor(.white)
                  .underline()
                  .padding([.top], Spacing.S4)
              }
            )
          }
        }
        .padding([.bottom], Spacing.L1)
      }

      Button(
        action: {
          if showSlider,
            let option = sliderSelectedOption
          {
            onSubscription(option)
          } else {
            onSubscription(selected)
          }
        },
        label: {
          Text(action.button)
            .contentShape(Rectangle())
            .font(Font(Fonts.headline))
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .foregroundColor(Color(UIColor(hex: "334046")))
            .background(Color.white)
            .cornerRadius(6)
        }
      )
      if let dismiss = action.dismiss {
        Button(
          action: {
            onDismiss()
          },
          label: {
            Text(dismiss)
              .underline()
              .font(Font(Fonts.body))
              .foregroundColor(.white)
          }
        )
        .padding([.top], Spacing.S5)
      }
      if let tipJar = action.tipJar {
        Button(
          action: {
            onTipJar(action.tipJarDisclaimer)
          },
          label: {
            Text(tipJar)
              .underline()
              .font(Font(Fonts.body))
              .foregroundColor(.white)
          }
        )
        .padding([.top], Spacing.S5)
      }
    }
  }
}

#Preview {
  ZStack {
    StoryBackgroundView()
    StoryActionView(
      action: .constant(
        .init(
          options: [
            .init(id: "supportTier4", title: "$3.99", price: 3.99),
            .init(id: "proMonthly", title: "$4.99", price: 4.99),
            .init(id: "supportTier10", title: "$9.99", price: 9.99),
          ],
          defaultOption: .init(id: "proMonthly", title: "$4.99", price: 4.99),
          sliderOptions: .init(min: 3.99, max: 9.99),
          button: "Continue"
        )
      ),
      onSubscription: { option in print(option.title) },
      onDismiss: {},
      onTipJar: { _ in }
    )
  }
}
