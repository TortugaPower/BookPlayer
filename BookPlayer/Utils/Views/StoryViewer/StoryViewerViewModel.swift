//
//  StoryTimer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/6/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class StoryViewerViewModel: ObservableObject {
  enum Routes {
    case showLoader(Bool)
    case showAlert(BPAlertContent)
    case success
    case dismiss
  }

  @Published var currentModel: StoryViewModel
  @Published var progress: Double = 0
  @Published var isOnLastStory: Bool = false

  let subscriptionService: StoryAccountSubscriptionProtocol
  public var storiesCount: Int { stories.count }

  /// Callback to handle actions on this screen
  var onTransition: BPTransition<Routes>?
  private var stories: [StoryViewModel]
  private let publisher: Timer.TimerPublisher
  private var cancellable: Cancellable?

  init(
    subscriptionService: StoryAccountSubscriptionProtocol,
    stories: [StoryViewModel]
  ) {
    self.subscriptionService = subscriptionService
    self.stories = stories
    self.currentModel = stories.first!
    self.publisher = Timer.publish(every: 0.1, on: .main, in: .default)
  }

  func start() {
    guard !UIAccessibility.isVoiceOverRunning else { return }

    cancellable?.cancel()
    cancellable = publisher.autoconnect().sink(receiveValue: { [weak self]  _ in
      guard let self else { return }
      var newProgress = self.progress + (0.1 / self.currentModel.duration)
      if Int(newProgress) >= self.storiesCount { newProgress = Double(self.storiesCount) - 0.01 }
      self.progress = newProgress
      self.currentModel = self.stories[Int(newProgress)]
    })
  }

  func next() {
    guard min(Int(progress) + 1, storiesCount) != storiesCount else {
      return
    }
    let newProgress = max((Int(progress) + 1) % storiesCount, 0)
    progress = Double(newProgress)
    isOnLastStory = stories.count - Int(progress) == 1
    currentModel = stories[newProgress]
  }

  func previous() {
    let newProgress = max((Int(self.progress) - 1) % storiesCount, 0)
    progress = Double(newProgress)
    isOnLastStory = stories.count - Int(progress) == 1
    currentModel = stories[newProgress]
  }

  func pause() {
    cancellable?.cancel()
  }

  func handleSubscription(option: PricingOption) {
    Task { @MainActor [weak self] in
      guard let self = self else { return }

      self.onTransition?(.showLoader(true))

      do {
        let userCancelled = try await self.subscriptionService.subscribe(option: option)
        self.onTransition?(.showLoader(false))
        if !userCancelled {
          self.onTransition?(.success)
        }
      } catch {
        self.onTransition?(.showLoader(false))
        self.onTransition?(.showAlert(
          BPAlertContent.errorAlert(message: error.localizedDescription)
        ))
      }
    }
  }

  func handleDismiss() {
    onTransition?(.dismiss)
  }
}
