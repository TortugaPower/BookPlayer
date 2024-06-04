//
//  StoryViewer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/6/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct StoryViewer: View {
  @State var firstSeen = false
  @ObservedObject var viewModel: StoryViewerViewModel

  var body: some View {
    ZStack(alignment: .top) {
      StoryBackgroundView()
        .accessibilityHidden(true)
      StoryProgress(
        storiesCount: .constant(viewModel.storiesCount),
        progress: $viewModel.progress
      )
      .padding([.trailing, .leading, .bottom])
      .accessibilityHidden(true)
      StoryView(
        model: $viewModel.currentModel,
        onPrevious: viewModel.previous,
        onNext: viewModel.next,
        onPause: viewModel.pause,
        onResume: viewModel.start,
        onSubscription: viewModel.handleSubscription(option:),
        onDismiss: viewModel.handleDismiss
      )
      .foregroundColor(Color.white)
      .padding()
      .offset(y: Spacing.L1)
    }
    .onAppear { viewModel.start() }
    .onChange(
      of: viewModel.currentModel,
      perform: { _ in
        UIAccessibility.post(notification: .screenChanged, argument: nil)
      })
  }
}

private class PreviewSubscriptionServiceMock: StoryAccountSubscriptionProtocol {
  func hasAccount() -> Bool {
    return true
  }
  
  func getSecondOnboarding<T: Decodable>() async throws -> T {
    throw BPSyncRefreshError.disabled
  }
  
  func subscribe(option: PricingOption) async throws -> Bool {
    return true
  }
}

#Preview {
  StoryViewer(
    viewModel: StoryViewerViewModel(
      subscriptionService: PreviewSubscriptionServiceMock(),
      stories: [
        StoryViewModel(
          title: "Story 1",
          body:
            "Body 1",
          image: "app-icon",
          duration: 10, action: .none),
        StoryViewModel(
          title: "Story 2",
          body:
            "Body 2",
          duration: 5,
          action: .init(
            options: [.supportTier4, .supportTier7, .supportTier10], defaultOption: .supportTier7,
            sliderOptions: .init(min: 3.99, max: 9.99), button: "Continue", dismiss: "Not now")),
      ]))
}
