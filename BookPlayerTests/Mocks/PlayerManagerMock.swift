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
  @Published var book: Book?
  var didTriggerPlayPause = false

  func playPause() {
    self.didTriggerPlayPause = true
  }

  func isPlayingPublisher() -> AnyPublisher<Bool, Never> {
    return Just(true).eraseToAnyPublisher()
  }

  func currentBookPublisher() -> Published<Book?>.Publisher {
    return self.$book
  }
}
