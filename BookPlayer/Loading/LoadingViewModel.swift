//
//  LoadingViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/9/21.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import CoreData
import Foundation

class LoadingViewModel: ViewModelProtocol {
  weak var coordinator: LoadingCoordinator!

  func initializeDataIfNeeded() {
    Task { @MainActor in
      let dataInitializerCoordinator = DataInitializerCoordinator(alertPresenter: self.coordinator)

      dataInitializerCoordinator.onFinish = {
        self.coordinator.didFinishLoadingSequence()
      }

      dataInitializerCoordinator.start()
    }
  }
}
