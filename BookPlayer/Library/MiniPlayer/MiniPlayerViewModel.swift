//
//  MiniPlayerViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import UIKit
import StoreKit

class MiniPlayerViewModel {
  struct Data {
    let title: String
    let author: String
    let relativePath: String
  }

  /// Available routes
  enum Routes {
    case showPlayer
    case loadItem(relativePath: String, autoplay: Bool, showPlayer: Bool)
  }
  /// Callback to handle actions on this screen
  public var onTransition: BPTransition<Routes>?

  private let playerManager: PlayerManagerProtocol
  public var currentItemInfo = CurrentValueSubject<Data?, Never>(nil)
  private var disposeBag = Set<AnyCancellable>()

  init(playerManager: PlayerManagerProtocol) {
    self.playerManager = playerManager

    bindObservers()
  }

  func bindObservers() {
    /// Drop initial value, as this viewModel already handles that
    self.playerManager.currentItemPublisher()
      .sink { [weak self] currentItem in
        guard let currentItem else {
          self?.currentItemInfo.value = nil
          return
        }

        self?.currentItemInfo.value = Data(
          title: currentItem.title,
          author: currentItem.author,
          relativePath: currentItem.relativePath
        )
      }
      .store(in: &disposeBag)
  }

  func isPlayingObserver() -> AnyPublisher<Bool, Never> {
    return self.playerManager.isPlayingPublisher()
  }

  func handlePlayPauseAction() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()

    if playerManager.hasLoadedBook() {
      playerManager.playPause()
    } else if let relativePath = currentItemInfo.value?.relativePath {
      onTransition?(.loadItem(relativePath: relativePath, autoplay: true, showPlayer: false))
    }
  }

  func showPlayer() {
    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    if playerManager.hasLoadedBook() {
      onTransition?(.showPlayer)
    } else if let relativePath = currentItemInfo.value?.relativePath {
      onTransition?(.loadItem(relativePath: relativePath, autoplay: false, showPlayer: true))
    }
  }
}
