//
//  LoadingOverlayModifier.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 1/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct LoadingOverlayModifier: ViewModifier {
  let isLoading: Bool
  var message: String?

  func body(content: Content) -> some View {
    content
      .overlay {
        if isLoading {
          VStack(spacing: 12) {
            ProgressView()
              .tint(.white)
            if let message {
              Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            }
          }
          .padding()
          .background(
            Color.black
              .opacity(0.9)
              .clipShape(RoundedRectangle(cornerRadius: 10))
          )
          .ignoresSafeArea(.all)
        }
      }
  }
}

struct LoadingOverlayWithConfettiModifier: ViewModifier {
  let isLoading: Bool
  let showConfetti: Bool

  func body(content: Content) -> some View {
    content
      .overlay {
        Group {
          ZStack {
            if showConfetti {
              ConfettiView()
            }
            if isLoading {
              ProgressView()
                .tint(.white)
                .padding()
                .background(
                  Color.black
                    .opacity(0.9)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                )
            }
          }
        }
        .ignoresSafeArea()
      }
  }
}

extension View {
  func loadingOverlay(_ isLoading: Bool, message: String? = nil) -> some View {
    modifier(LoadingOverlayModifier(isLoading: isLoading, message: message))
  }

  func loadingOverlayWithConfetti(_ isLoading: Bool, showConfetti: Bool) -> some View {
    modifier(LoadingOverlayWithConfettiModifier(isLoading: isLoading, showConfetti: showConfetti))
  }
}
