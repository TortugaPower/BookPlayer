//
//  JellyfinConnectionViewModel.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-25.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI
import Combine

class JellyfinConnectionViewModel: ViewModelProtocol {
  /// Possible routes for the screen
  enum Routes {
    case cancel
  }

  var formViewModel: JellyfinConnectionFormViewModel = JellyfinConnectionFormViewModel()

  func createCanConnectPublisher() -> AnyPublisher<Bool, Never> {
    formViewModel.$serverUrl.map { !$0.isEmpty }.eraseToAnyPublisher()
  }

  weak var coordinator: ItemListCoordinator!

  /// Callback to handle actions on this screen
  public var onTransition: BPTransition<Routes>?

  func handleCancelAction() {
    onTransition?(.cancel)
  }
}
