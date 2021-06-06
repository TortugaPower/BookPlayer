//
//  DataMigrationManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 19/2/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

class DataMigrationManager {
    let enableMigrations: Bool
    let modelName: String
    let storeName = "BookPlayer"
    var stack: CoreDataStack {
        guard self.enableMigrations, !self.store(at: self.storeURL, isCompatibleWithModel: self.currentModel)
        else {
            return CoreDataStack(modelName: self.modelName)
        }
        self.performMigration()
        return CoreDataStack(modelName: self.modelName)
    }

    private var applicationSupportURL: URL {
        let path = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory,
                                                       .userDomainMask, true)
            .first
        return URL(fileURLWithPath: path!)
    }

    private lazy var storeURL: URL = {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!.appendingPathComponent("\(self.storeName).sqlite")
    }()

    private var storeModel: NSManagedObjectModel? {
        return NSManagedObjectModel.modelVersionsFor(modelNamed: self.modelName)
            .filter {
                self.store(at: storeURL, isCompatibleWithModel: $0)
            }.first
    }

    private lazy var currentModel: NSManagedObjectModel = .model(named: self.modelName)

    init(modelNamed: String, enableMigrations: Bool = false) {
        self.modelName = modelNamed
        self.enableMigrations = enableMigrations
    }

    private func store(at storeURL: URL, isCompatibleWithModel model: NSManagedObjectModel) -> Bool {
        let storeMetadata = self.metadataForStoreAtURL(storeURL: storeURL)

        return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: storeMetadata)
    }

    private func metadataForStoreAtURL(storeURL: URL) -> [String: Any] {
        let metadata: [String: Any]
        do {
            metadata = try NSPersistentStoreCoordinator
                .metadataForPersistentStore(ofType: NSSQLiteStoreType,
                                            at: storeURL, options: nil)
        } catch {
            metadata = [:]
            print("Error retrieving metadata for store at URL: \(storeURL): \(error)")
        }
        return metadata
    }

    private func migrateStoreAt(URL storeURL: URL,
                                fromModel from: NSManagedObjectModel,
                                toModel to: NSManagedObjectModel,
                                mappingModel: NSMappingModel? = nil) {
        let migrationManager = NSMigrationManager(sourceModel: from, destinationModel: to)

        let migrationMappingModel = try? mappingModel
            ?? NSMappingModel.inferredMappingModel(forSourceModel: from, destinationModel: to)

        let targetURL = storeURL.deletingLastPathComponent()
        let destinationName = storeURL.lastPathComponent + "~1"
        let destinationURL = targetURL.appendingPathComponent(destinationName)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }

        let success: Bool
        do {
            try migrationManager.migrateStore(from: storeURL,
                                              sourceType: NSSQLiteStoreType,
                                              options: nil,
                                              with: migrationMappingModel,
                                              toDestinationURL: destinationURL,
                                              destinationType: NSSQLiteStoreType,
                                              destinationOptions: nil)
            success = true
        } catch {
            success = false
            fatalError("Migration failed \(error), \(error.localizedDescription)")
        }

        if success {
            let fileManager = FileManager.default
            let wal = storeURL.lastPathComponent + "-wal"
            let shm = storeURL.lastPathComponent + "-shm"
            let destinationWal = targetURL
                .appendingPathComponent(wal)
            let destinationShm = targetURL
                .appendingPathComponent(shm)
            // cleanup in case
            try? fileManager.removeItem(at: destinationWal)
            try? fileManager.removeItem(at: destinationShm)

            do {
                try fileManager.removeItem(at: storeURL)
                try fileManager.moveItem(at: destinationURL, to: storeURL)
            } catch {
                fatalError("Error moving database: \(error), \(error.localizedDescription)")
            }
        }
    }

    func performMigration() {
        guard let storeModel = self.storeModel else { return }

        if storeModel.isVersion1 {
            let destinationModel = NSManagedObjectModel.version2

            let mapPath = Bundle.main.path(forResource: "MappingModel_v1_to_v2", ofType: "cdm")!
            let mapUrl = URL(fileURLWithPath: mapPath)

            let mappingModel = NSMappingModel(contentsOf: mapUrl)

            self.migrateStoreAt(URL: self.storeURL,
                                fromModel: storeModel,
                                toModel: destinationModel,
                                mappingModel: mappingModel)
            self.performMigration()
        } else if storeModel.isVersion2 {
            let destinationModel = NSManagedObjectModel.version3

            let mapPath = Bundle.main.path(forResource: "MappingModel_v2_to_v3", ofType: "cdm")!
            let mapUrl = URL(fileURLWithPath: mapPath)

            let mappingModel = NSMappingModel(contentsOf: mapUrl)

            self.migrateStoreAt(URL: storeURL,
                                fromModel: storeModel,
                                toModel: destinationModel,
                                mappingModel: mappingModel)
            self.performMigration()
        } else if storeModel.isVersion3 {
            let destinationModel = NSManagedObjectModel.version4

            let mapPath = Bundle.main.path(forResource: "MappingModel_v3_to_v4", ofType: "cdm")!
            let mapUrl = URL(fileURLWithPath: mapPath)

            let mappingModel = NSMappingModel(contentsOf: mapUrl)

            self.migrateStoreAt(URL: storeURL,
                                fromModel: storeModel,
                                toModel: destinationModel,
                                mappingModel: mappingModel)

            // Migrate folder hierarchy
            self.migrateFolderHierarchy()
            // Migrate books names
            self.migrateBooks()
        }
    }
}

extension NSManagedObjectModel {
    private class func modelURLs(in modelFolder: String) -> [URL] {
        return Bundle.main
            .urls(forResourcesWithExtension: "mom",
                  subdirectory: "\(modelFolder).momd") ?? []
    }

    class func modelVersionsFor(modelNamed modelName: String) -> [NSManagedObjectModel] {
        return self.modelURLs(in: modelName)
            .compactMap(NSManagedObjectModel.init)
    }

    class func bookplayerModel(named modelName: String) -> NSManagedObjectModel {
        let model = self.modelURLs(in: "BookPlayer")
            .filter { $0.lastPathComponent == "\(modelName).mom" }
            .first
            .flatMap(NSManagedObjectModel.init)
        return model ?? NSManagedObjectModel()
    }

    class var version1: NSManagedObjectModel {
        return bookplayerModel(named: "Audiobook Player")
    }

    var isVersion1: Bool {
        return self == type(of: self).version1
    }

    class var version2: NSManagedObjectModel {
        return bookplayerModel(named: "Audiobook Player 2")
    }

    var isVersion2: Bool {
        return self == type(of: self).version2
    }

    class var version3: NSManagedObjectModel {
        return bookplayerModel(named: "Audiobook Player 3")
    }

    var isVersion3: Bool {
        return self == type(of: self).version3
    }

    class var version4: NSManagedObjectModel {
        return bookplayerModel(named: "Audiobook Player 4")
    }

    var isVersion4: Bool {
        return self == type(of: self).version4
    }

    class func model(named modelName: String, in bundle: Bundle = .main) -> NSManagedObjectModel {
        return bundle.url(forResource: modelName, withExtension: "momd")
            .flatMap(NSManagedObjectModel.init)
            ?? NSManagedObjectModel()
    }
}

func == (firstModel: NSManagedObjectModel,
         otherModel: NSManagedObjectModel) -> Bool {
    return firstModel.entitiesByName == otherModel.entitiesByName
}
