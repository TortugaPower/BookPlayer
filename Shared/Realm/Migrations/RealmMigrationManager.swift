//
//  RealmMigrationManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 24/2/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import RealmSwift

protocol MigrationHandler {
  func migrate(_ migration: Migration, _ oldSchemaVersion: UInt64)
}

class RealmMigrationManager: MigrationHandler {

  private var handlers: [MigrationHandler] = [
    MigrationStoredSyncTasks()
  ]

  func migrate(_ migration: RealmSwift.Migration, _ oldSchemaVersion: UInt64) {
    for handler in handlers {
      handler.migrate(migration, oldSchemaVersion)
    }
  }
}
