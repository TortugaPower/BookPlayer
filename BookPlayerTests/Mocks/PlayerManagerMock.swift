//
//  PlayerManagerMock.swift
//  BookPlayerTests
//
//  Created by Gianni Carlo on 11/20/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation
@testable import BookPlayer

class PlayerManagerMock: PlayerManagerProtocol {
  @Published var currentItem: PlayableItem?
  @Published var currentSpeed: Float = 1.0
  var didPlayPause = false

  func playPause() {
    self.didPlayPause = true
  }

  func isPlayingPublisher() -> AnyPublisher<Bool, Never> {
    return Just(true).eraseToAnyPublisher()
  }

  func currentItemPublisher() -> Published<PlayableItem?>.Publisher {
    return self.$currentItem
  }

  func play() {}

  func pause(fade: Bool) {}

  func stop() {}

  func load(_ item: PlayableItem) {
    NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["loaded": true])
  }

  func hasLoadedBook() -> Bool { return true }

  func rewind() {}

  func forward() {}

  func jumpTo(_ time: Double, recordBookmark: Bool) {}

  func markAsCompleted(_ flag: Bool) {}

  func playPreviousItem() {}

  func playNextItem(autoPlayed: Bool) {}

  func playItem(_ item: PlayableItem) {}

  func getSpeedOptions() -> [Float] { return [] }

  func getCurrentSpeed() -> Float { return 1.0 }

  func currentSpeedPublisher() -> AnyPublisher<Float, Never> {
    return self.$currentSpeed.eraseToAnyPublisher()
  }

  func setSpeed(_ newValue: Float, relativePath: String?) {}
}
