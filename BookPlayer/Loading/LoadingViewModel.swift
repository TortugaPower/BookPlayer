//
//  LoadingViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import CoreData
import Foundation

class LoadingViewModel: ViewModelProtocol {
  weak var coordinator: LoadingCoordinator!

  @MainActor
  func initializeDataIfNeeded() {
    let dataInitializerCoordinator = DataInitializerCoordinator(alertPresenter: self.coordinator)

    dataInitializerCoordinator.onFinish = { stack in
      self.coordinator.didFinishLoadingSequence(coreDataStack: stack)
    }

    dataInitializerCoordinator.start()
  }
}
