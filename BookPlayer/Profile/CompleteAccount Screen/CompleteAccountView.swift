//
//  CompleteAccountView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/7/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct CompleteAccountView<Model: CompleteAccountViewModelProtocol>: View {
  @StateObject var themeViewModel = ThemeViewModel()
  @ObservedObject var viewModel: Model

  var disclaimerView: some View {
    return Text("\("agreement_prefix_title".localized) [\("privacy_policy_title".localized)](https://github.com/TortugaPower/BookPlayer/blob/main/PRIVACY_POLICY.md) \("and_title".localized) [\("terms_conditions_title".localized)](https://github.com/TortugaPower/BookPlayer/blob/main/TERMS_CONDITIONS.md)")
      .fixedSize(horizontal: false, vertical: true)
      .multilineTextAlignment(.center)
  }

  var body: some View {
    VStack(spacing: Spacing.S1) {
      Text("choose_plan_title".localized)
        .font(Font(Fonts.body))
        .foregroundColor(themeViewModel.secondaryColor)
        .padding(.top, Spacing.M)

      PricingOptionsView(
        options: $viewModel.pricingOptions,
        selected: $viewModel.selectedPricingOption,
        isLoading: $viewModel.isLoadingPricingOptions,
        onSelected: { option in
          viewModel.selectedPricingOption = option
        }
      )

      Button(action: viewModel.handleSubscription) {
        Text("subscribe_title".localized)
          .contentShape(Rectangle())
          .font(Font(Fonts.headline))
          .frame(height: 45)
          .frame(maxWidth: .infinity)
          .foregroundColor(.white)
          .background(Color(UIColor(hex: "687AB7")))
          .cornerRadius(6)
          .padding(.top, Spacing.S1)
      }

      disclaimerView
        .font(Font(Fonts.body))

      Spacer()
    }
    .padding([.leading, .trailing], Spacing.M)
    .environmentObject(themeViewModel)
    .navigationTitle("BookPlayer Pro")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .navigationBarLeading) {
        Button(
          action: viewModel.dismiss,
          label: {
            Image(systemName: "xmark")
              .foregroundColor(themeViewModel.linkColor)
          }
        )
      }
      ToolbarItem(placement: .navigationBarTrailing) {
        Button(
          action: viewModel.handleRestorePurchases,
          label: {
            Text("restore_title".localized)
              .foregroundColor(themeViewModel.linkColor)
          }
        )
      }
    }
    .alert(isPresented: $viewModel.networkError.isNotNil()) {
      Alert(
        title: Text("error_title".localized),
        message: Text(viewModel.networkError!.localizedDescription),
        dismissButton: .default(Text("ok_button".localized))
      )
    }
  }
}

struct CompleteAccountView_Previews: PreviewProvider {
  class MockCompleteAccountViewModel: CompleteAccountViewModelProtocol, ObservableObject {
    var pricingOptions = [
      PricingModel(id: "1", title: "49.99 USD per month", price: 49.99),
      PricingModel(id: "2", title: "4.99 USD per month", price: 4.99)
    ]
    var selectedPricingOption: PricingModel? = PricingModel(id: "1", title: "49.99 USD per month", price: 49.99)
    var isLoadingPricingOptions: Bool = false
    var networkError: Error?

    func handleSubscription() {}

    func handleRestorePurchases() {}

    func dismiss() {}
  }
  static var previews: some View {
    CompleteAccountView(viewModel: MockCompleteAccountViewModel())
  }
}
