//
//  CoreDataStack.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/2/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

public class CoreDataStack {
  private let modelName: String
  private let loadCompletionHandler: (NSPersistentStoreDescription, Error?) -> Void

    public lazy var managedContext: NSManagedObjectContext = {
      self.storeContainer.viewContext.undoManager = nil
      return self.storeContainer.viewContext
    }()

    public lazy var storeUrl: URL = {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!.appendingPathComponent("BookPlayer.sqlite")
    }()

  public init(modelName: String, loadCompletionHandler: @escaping (NSPersistentStoreDescription, Error?) -> Void) {
    self.modelName = modelName
    self.loadCompletionHandler = loadCompletionHandler
  }

    private lazy var storeContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: self.modelName)

        let description = NSPersistentStoreDescription()
        description.shouldInferMappingModelAutomatically = false
        description.shouldMigrateStoreAutomatically = true
        description.url = self.storeUrl

        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores(completionHandler: self.loadCompletionHandler)

        return container
    }()

    public func saveContext() {
        guard self.managedContext.hasChanges else { return }
        do {
            try self.managedContext.save()
        } catch let error as NSError {
            fatalError("Unresolved error \(error), \(error.userInfo)")
        }
    }

    public func getBackgroundContext() -> NSManagedObjectContext {
        return self.storeContainer.newBackgroundContext()
    }
}
