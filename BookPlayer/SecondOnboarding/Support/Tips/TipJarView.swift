//
//  TipJarView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/2/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct TipJarView: View {
  @ObservedObject var viewModel: TipJarViewModel
  @StateObject var themeViewModel = ThemeViewModel()
  @State var selected: TipOption = TipOption.excellent
  @State var error: Error?

  var body: some View {
    NavigationView {
      VStack {
        if let disclaimer = viewModel.disclaimer {
          Text(disclaimer)
            .foregroundColor(themeViewModel.primaryColor)
            .font(Font(Fonts.titleRegular))
            .padding()
        }

        HStack(spacing: Spacing.S1) {
          Spacer()
          ForEach(TipOption.allCases) { option in
            TipOptionView(
              title: .constant(option.title),
              price: .constant(option.price),
              isSelected: .constant(selected == option)
            )
            .onTapGesture {
              selected = option
            }
          }
          Spacer()
        }
        Button(action: {
          Task { @MainActor in
            await viewModel.donate(selected)
          }
        }) {
          Text("Donate")
            .contentShape(Rectangle())
            .font(Font(Fonts.headline))
            .frame(height: 45)
            .frame(maxWidth: .infinity)
            .foregroundColor(.white)
            .background(Color(UIColor(hex: "687AB7")))
            .cornerRadius(6)
            .padding(.top, Spacing.S1)
        }
        Spacer()
      }
      .padding(.horizontal, Spacing.M)
      .background(themeViewModel.systemGroupedBackgroundColor)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button {
            viewModel.dismiss()
          } label: {
            Image(systemName: "xmark")
          }
        }

        ToolbarItem(placement: .confirmationAction) {
          Button("Restore") {
            Task { @MainActor in
              await viewModel.restorePurchases()
            }
          }
        }
      }
      .navigationTitle("Tip Jar")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}
