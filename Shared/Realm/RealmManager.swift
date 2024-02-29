//
//  RealmManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/2/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import Foundation
import RealmSwift

public class RealmManager {
  public static let shared = RealmManager()

  private let migrationManager = RealmMigrationManager()

  private lazy var tasksConfiguration = Realm.Configuration(
    fileURL: DataManager.getSyncTasksRealmURL(),
    schemaVersion: 1
  ) { migration, oldSchemaVersion in
    self.migrationManager.migrate(migration, oldSchemaVersion)
  }

  func initializeRealm(in actor: Actor) async throws -> Realm {
    return try await Realm(configuration: tasksConfiguration, actor: actor)
  }

  func publisher<Element: RealmFetchable>(
    for type: Element.Type,
    keyPaths: [String]?,
    block: @escaping (RealmCollectionChange<Results<Element>>) -> Void
  ) -> NotificationToken {
    let realm = try! Realm(configuration: tasksConfiguration)
    return realm.objects(type).observe(keyPaths: keyPaths, on: DispatchQueue.main, block)
  }
}
