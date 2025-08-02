//
//  SettingsTipView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import RevenueCat
import SwiftUI

struct SettingsTipView: View {
  let tipOption: TipOption

  @State private var buttonTitle = ""
  @State private var isLoading = false
  @State private var product: StoreProduct?
  @State private var loadProductTask: Task<(), Error>?
  @EnvironmentObject private var theme: ThemeViewModel
  @Environment(\.loadingState) var loadingState

  let purchaseCompleted: () -> Void

  var buttonBackgroundColor: Color {
    switch tipOption {
    case .kind:
      return Color(UIColor(hex: "528CCD"))
    case .excellent:
      return Color(UIColor(hex: "687AB7"))
    case .incredible:
      return Color(UIColor(hex: "6565AB"))
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      Text(tipOption.title)
        .foregroundStyle(theme.secondaryColor)
        .bpFont(Fonts.captionMedium)
        .multilineTextAlignment(.center)
        .lineLimit(2)
        .padding(.bottom, Spacing.S3)
      if isLoading {
        ProgressView()
          .tint(.white)
          .frame(width: 75, height: 28)
          .background(buttonBackgroundColor)
          .mask(Capsule())
      } else {
        Button(
          buttonTitle.isEmpty
            ? tipOption.price
            : buttonTitle
        ) {
          self.isLoading = true

          Task { @MainActor in
            do {
              try await purchaseProduct()
              self.isLoading = false
            } catch {
              self.isLoading = false
              self.loadingState.error = error
            }
          }
        }
        .bpFont(Fonts.caption)
        .padding(.horizontal)
        .frame(width: 75, height: 28)
        .foregroundStyle(.white)
        .background(buttonBackgroundColor)
        .mask(Capsule())
      }
    }
    .onAppear {
      loadProduct()
    }
    .padding(Spacing.S1)
    .background(.white)
    .mask(RoundedRectangle(cornerRadius: 5, style: .continuous))
  }

  func loadProduct() {
    loadProductTask = Task {
      self.isLoading = true
      let products = await Purchases.shared.products([tipOption.rawValue])
      self.product = products.first
      self.buttonTitle = self.product?.localizedPriceString ?? ""
      self.isLoading = false
    }
  }

  func purchaseProduct() async throws {
    _ = await loadProductTask?.result

    guard let product else {
      throw "network_error_title".localized
    }

    let result = try await Purchases.shared.purchase(product: product)

    guard !result.userCancelled else { return }

    purchaseCompleted()
  }
}

#Preview {
  SettingsTipView(
    tipOption: TipOption.kind
  ) {}
  .environmentObject(ThemeViewModel())
}
