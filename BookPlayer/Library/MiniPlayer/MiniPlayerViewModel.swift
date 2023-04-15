//
//  MiniPlayerViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import UIKit
import StoreKit

class MiniPlayerViewModel {
  typealias Data = (title: String, author: String, relativePath: String)
  /// Available routes
  enum Routes {
    case showPlayer
    case loadItem(relativePath: String, autoplay: Bool, showPlayer: Bool)
  }
  /// Callback to handle actions on this screen
  public var onTransition: Transition<Routes>?

  private let playerManager: PlayerManagerProtocol
  public var currentItemInfo = CurrentValueSubject<Data?, Never>(nil)
  private var disposeBag = Set<AnyCancellable>()

  init(
    playerManager: PlayerManagerProtocol,
    lastPlayedItem: SimpleLibraryItem?
  ) {
    self.playerManager = playerManager

    if let lastPlayedItem {
      self.currentItemInfo.value = Data((
        title: lastPlayedItem.title,
        author: lastPlayedItem.details,
        relativePath: lastPlayedItem.relativePath
      ))
    }

    bindObservers()
  }

  func bindObservers() {
    /// Drop initial value, as this viewModel already handles that
    self.playerManager.currentItemPublisher()
      .dropFirst()
      .sink { [weak self] currentItem in
        guard let currentItem else {
          self?.currentItemInfo.value = nil
          return
        }

        self?.currentItemInfo.value = Data((
          title: currentItem.title,
          author: currentItem.author,
          relativePath: currentItem.relativePath
        ))
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
