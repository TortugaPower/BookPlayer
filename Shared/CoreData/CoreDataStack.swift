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
  private let storeUrl: URL
  private let storeContainer: NSPersistentContainer

  public var managedContext: NSManagedObjectContext {
    return self.storeContainer.viewContext
  }

  public init(modelName: String) {
    self.modelName = modelName
    let storeUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!.appendingPathComponent("BookPlayer.sqlite")
    self.storeUrl = storeUrl
    self.storeContainer = NSPersistentContainer(name: modelName)

    let description = NSPersistentStoreDescription()
    description.shouldInferMappingModelAutomatically = false
    description.shouldMigrateStoreAutomatically = true
    description.url = self.storeUrl

    self.storeContainer.persistentStoreDescriptions = [description]
  }

  public init(testPath: String) {
    let modelName = "BookPlayer"
    self.modelName = modelName
    let storeUrl = URL(fileURLWithPath: testPath)
    self.storeUrl = storeUrl
    self.storeContainer = NSPersistentContainer(name: modelName)

    let description = NSPersistentStoreDescription()
    description.shouldInferMappingModelAutomatically = false
    description.shouldMigrateStoreAutomatically = true
    description.url = self.storeUrl

    self.storeContainer.persistentStoreDescriptions = [description]
    self.storeContainer.loadPersistentStores { _, _ in }
  }

  public func loadStore(completionHandler: ((NSPersistentStoreDescription, Error?) -> Void)?) {
    self.storeContainer.loadPersistentStores { storeDescription, error in
      self.storeContainer.viewContext.undoManager = nil
      completionHandler?(storeDescription, error)
    }
  }

  public func saveContext() {
    saveContext(managedContext)
  }

  public func saveContext(_ context: NSManagedObjectContext) {
    guard context.hasChanges else { return }
    do {
      try context.save()
    } catch let error as NSError {
      fatalError("Unresolved error \(error), \(error.userInfo)")
    }
  }

  public func getBackgroundContext() -> NSManagedObjectContext {
    return self.storeContainer.newBackgroundContext()
  }
}
