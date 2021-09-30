//
//  LoadingViewModel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 26/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation

class LoadingViewModel {
  var coordinator: LoadingCoordinator!
  let dataMigrationManager: DataMigrationManager

  init(dataMigrationManager: DataMigrationManager) {
    self.dataMigrationManager = dataMigrationManager
  }

  func setupDefaultState() {
    self.dataMigrationManager.setupDefaultState()
  }

  func performMigrations() {
    if self.dataMigrationManager.canPeformMigration() {
      self.handleMigrations()
    } else {
      self.loadLibrary()
    }
  }

  private func handleMigrations() {
    guard self.dataMigrationManager.needsMigration() else {
      self.loadLibrary()
      return
    }

    do {
      try self.dataMigrationManager.performMigration { [weak self] error in
        if let error = error {
          self?.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
          return
        }

        self?.handleMigrations()
      }
    } catch {
      self.coordinator.showAlert("error_title".localized, message: error.localizedDescription)
    }
  }

  func loadLibrary() {
    let stack = self.dataMigrationManager.getCoreDataStack()

    stack.loadStore { _, error in
      print("=== error: \(error)")

      let dataManager = DataManager(coreDataStack: stack)

      let test = dataManager.getSelectedTheme()
      print(test)
      let tests = dataManager.getAllThemes()
      print(tests)

      self.coordinator.didFinishLoadingSequence(coreDataStack: stack)
    }
  }
}
