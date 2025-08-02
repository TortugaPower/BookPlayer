//
//  CompleteAccountView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 3/7/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct CompleteAccountView: View {
  @State private var pricingOptions: [PricingModel] = [
    .init(id: "placeholder_1", title: "", price: 0),
    .init(id: "placeholder_2", title: "", price: 0),
  ]
  @State private var selectedPricingOption: PricingModel?
  @State private var isLoadingPricingOptions: Bool = true

  @State private var loadingState = LoadingOverlayState()
  @State private var showConfetti = false
  @State private var showSuccessAlert = false

  @Environment(\.accountService) private var accountService
  @EnvironmentObject private var theme: ThemeViewModel

  var onDismiss: () -> Void

  var body: some View {
    VStack(spacing: Spacing.S1) {
      Text("choose_plan_title")
        .font(Font(Fonts.body))
        .foregroundStyle(theme.secondaryColor)
        .padding(.top, Spacing.M)

      PricingOptionsView(
        options: $pricingOptions,
        selected: $selectedPricingOption,
        isLoading: $isLoadingPricingOptions
      )

      Button {
        guard
          isLoadingPricingOptions == false,
          let selectedOption = selectedPricingOption
        else { return }

        loadingState.show = true

        Task { @MainActor in
          do {
            let userCancelled = try await self.accountService.subscribe(option: selectedOption)
            loadingState.show = false
            if !userCancelled {
              /// Register that there was a subscription
              BPSKANManager.updateConversionValue(.subscription)
              showCongrats()
            }
          } catch {
            loadingState.show = false
            loadingState.error = error
          }
        }
      } label: {
        Text("subscribe_title")
          .contentShape(Rectangle())
          .bpFont(Fonts.headline)
          .frame(height: 45)
          .frame(maxWidth: .infinity)
          .foregroundStyle(.white)
          .background(Color(UIColor(hex: "687AB7")))
          .cornerRadius(6)
          .padding(.top, Spacing.S1)
      }

      disclaimerView

      Spacer()
    }
    .padding([.leading, .trailing], Spacing.M)
    .loadingOverlayWithConfetti(
      loadingState.show,
      showConfetti: showConfetti
    )
    .errorAlert(error: $loadingState.error)
    .navigationTitle("BookPlayer Pro")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        Button(
          action: onDismiss,
          label: {
            Image(systemName: "xmark")
              .foregroundStyle(theme.linkColor)
          }
        )
      }
      ToolbarItem(placement: .confirmationAction) {
        Button("restore_title") {
          PurchasesManager.restoreSubscriptions(
            loadingState: loadingState,
            onSuccess: showCongrats
          )
        }
        .foregroundStyle(theme.linkColor)
      }
    }
    .alert("pro_welcome_title", isPresented: $showSuccessAlert) {
      Button("ok_title") {
        onDismiss()
      }
    } message: {
      Text("pro_welcome_description")
    }
    .onAppear {
      Task {
        do {
          try await loadProducts()
        } catch {
          loadingState.error = error
        }
      }
    }
  }

  var disclaimerView: some View {
    return Text(
      "\("agreement_prefix_title".localized) [\("privacy_policy_title".localized)](https://github.com/TortugaPower/BookPlayer/blob/main/PRIVACY_POLICY.md) \("and_title".localized) [\("terms_conditions_title".localized)](https://github.com/TortugaPower/BookPlayer/blob/main/TERMS_CONDITIONS.md)"
    )
    .fixedSize(horizontal: false, vertical: true)
    .multilineTextAlignment(.center)
    .bpFont(Fonts.body)
  }

  func showCongrats() {
    showConfetti = true
    showSuccessAlert = true
  }

  func loadProducts() async throws {
    let options = try await accountService.getSubscriptionOptions()
    pricingOptions = options
    selectedPricingOption = options.first
    isLoadingPricingOptions = false
  }
}
