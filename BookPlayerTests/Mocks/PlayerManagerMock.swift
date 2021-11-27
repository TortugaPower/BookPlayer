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
  @Published var currentBook: Book?
  @Published var currentSpeed: Float = 1.0
  @Published var hasChapters = false
  var didPlayPause = false

  func playPause() {
    self.didPlayPause = true
  }

  func isPlayingPublisher() -> AnyPublisher<Bool, Never> {
    return Just(true).eraseToAnyPublisher()
  }

  func currentBookPublisher() -> Published<Book?>.Publisher {
    return self.$currentBook
  }

  func play() {}

  func pause(fade: Bool) {}

  func stop() {}

  func load(_ book: Book, completion: @escaping (Bool) -> Void) {}

  func hasLoadedBook() -> Bool { return true }

  func rewind() {}

  func forward() {}

  func jumpTo(_ time: Double, recordBookmark: Bool) {}

  func markAsCompleted(_ flag: Bool) {}

  func playPreviousItem() {}

  func playNextItem(autoPlayed: Bool) {}

  func playItem(_ book: Book) {}

  func hasChaptersPublisher() -> Published<Bool>.Publisher {
    return self.$hasChapters
  }

  func getSpeedOptions() -> [Float] { return [] }

  func getCurrentSpeed() -> Float { return 1.0 }

  func currentSpeedPublisher() -> AnyPublisher<Float, Never> {
    return self.$currentSpeed.eraseToAnyPublisher()
  }

  func setSpeed(_ newValue: Float, relativePath: String?) {}
}
