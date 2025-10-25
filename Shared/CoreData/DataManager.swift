//
//  DataManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/3/19.
//  Copyright © 2019 BookPlayer LLC. All rights reserved.
//

import CoreData
import Foundation

public class DataManager {
  public static let processedFolderName = "Processed"
  public static let backupFolderName = "BPBackup"
  public static let inboxFolderName = "Inbox"
  public static let sharedFolderName = "SharedBP"
  public static let trashFolderName = ".Trash"
  public static var loadingDataError: Error?
  private let coreDataStack: CoreDataStack
  private var pendingSaveContext: DispatchWorkItem?
  private static var documentsFolderURL: URL = {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  }()
  private static var applicationSupportFolderURL: URL = {
    return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
  }()
  /// Prefer using this instead of ``getProcessedFolderURL()``, as it's calculated just once
  public static var processedFolderURL: URL = {
    let documentsURL = documentsFolderURL

    let processedFolderURL = documentsURL.appendingPathComponent(processedFolderName)

    if !FileManager.default.fileExists(atPath: processedFolderURL.path) {
      do {
        try FileManager.default.createDirectory(at: processedFolderURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
        fatalError("Couldn't create Processed folder")
      }
    }

    return processedFolderURL
  }()

  public init(coreDataStack: CoreDataStack) {
    self.coreDataStack = coreDataStack
  }
  // MARK: - Folder URLs

  public class func getDocumentsFolderURL() -> URL {
    return documentsFolderURL
  }

  public class func getApplicationSupportFolderURL() -> URL {
    let contents = try! FileManager.default.contentsOfDirectory(atPath: "\(applicationSupportFolderURL.path)/DatabaseBackups")
    print(contents)
    return applicationSupportFolderURL
  }

  /// Keeping original implementation due to unit tests behaviors
  public class func getProcessedFolderURL() -> URL {
    let processedFolderURL = documentsFolderURL.appendingPathComponent(processedFolderName)

    if !FileManager.default.fileExists(atPath: processedFolderURL.path) {
      do {
        try FileManager.default.createDirectory(at: processedFolderURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
        fatalError("Couldn't create Processed folder")
      }
    }

    return processedFolderURL
  }

  public class func getSyncTasksRealmURL() -> URL {
    let hiddenFolderURL = self.getDocumentsFolderURL()
      .appendingPathComponent(self.processedFolderName)
      .appendingPathComponent(".dbRealm")

    if !FileManager.default.fileExists(atPath: hiddenFolderURL.path) {
      do {
        try FileManager.default.createDirectory(
          at: hiddenFolderURL,
          withIntermediateDirectories: true,
          attributes: nil
        )
      } catch {
        fatalError("Couldn't create Realm folder")
      }
    }

    return hiddenFolderURL.appendingPathComponent("bookplayer-synctasks.realm")
  }

  public class func getSyncTasksSwiftDataURL() -> URL {
    let folderURL = getApplicationSupportFolderURL()

    return folderURL.appendingPathComponent("bp-synctasks.sqlite")
  }

  public class func getBackupFolderURL() -> URL {
    let documentsURL = self.getDocumentsFolderURL()

    let backupFolderURL = documentsURL.appendingPathComponent(self.backupFolderName)

    if !FileManager.default.fileExists(atPath: backupFolderURL.path) {
      do {
        try FileManager.default.createDirectory(at: backupFolderURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
        fatalError("Couldn't create Backup folder")
      }
    }

    return backupFolderURL
  }

  public class func getDatabaseBackupFolderURL() -> URL {
    let appSupportURL = self.getApplicationSupportFolderURL()

    let backupFolderURL = appSupportURL.appendingPathComponent("DatabaseBackups")

    if !FileManager.default.fileExists(atPath: backupFolderURL.path) {
      do {
        try FileManager.default.createDirectory(at: backupFolderURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
        fatalError("Couldn't create Database Backup folder")
      }
    }

    return backupFolderURL
  }

  public class func getInboxFolderURL() -> URL {
    let documentsURL = self.getDocumentsFolderURL()

    let inboxFolderURL = documentsURL.appendingPathComponent(self.inboxFolderName)

    return inboxFolderURL
  }

  public class func getSharedFilesFolderURL() -> URL {
    let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.ApplicationGroupIdentifier)!

    let sharedFolderURL = containerURL.appendingPathComponent(self.sharedFolderName)

    if !FileManager.default.fileExists(atPath: sharedFolderURL.path) {
      do {
        try FileManager.default.createDirectory(at: sharedFolderURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
        fatalError("Couldn't create Shared folder")
      }
    }

    return sharedFolderURL
  }

  public class func isURLInProcessedFolder(_ url: URL) -> Bool {
    let absoluteUrl = url.resolvingSymlinksInPath().absoluteString
    let processedFolderUrl = getProcessedFolderURL().absoluteString
    return absoluteUrl.contains(processedFolderUrl)
  }

  /// Create the parent folder (and intermediates) for a file URL if necessary
  public class func createContainingFolderIfNeeded(for url: URL) throws {
    let processedFolder = DataManager.getProcessedFolderURL()

    let containingFolder = url.deletingLastPathComponent()

    guard 
      processedFolder != containingFolder,
      !FileManager.default.fileExists(atPath: containingFolder.path)
    else { return }

    try FileManager.default.createDirectory(at: containingFolder, withIntermediateDirectories: true)
  }

  /// Create the folder on disk if needed for the passed URL
  public class func createBackingFolderIfNeeded(_ url: URL) throws {
    if !FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
  }

  public func getContext() -> NSManagedObjectContext {
    return self.coreDataStack.managedContext
  }

  public func scheduleSaveContext() {
    guard self.pendingSaveContext == nil else { return }

    let workItem = DispatchWorkItem { [weak self] in
      self?.coreDataStack.saveContext()
      self?.pendingSaveContext = nil
    }

    self.pendingSaveContext = workItem

    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2), execute: workItem)
  }

  public func saveContext() {
    self.coreDataStack.saveContext()
  }

  public func saveSyncContext(_ context: NSManagedObjectContext) {
    coreDataStack.saveContext(context)
  }

  public func getBackgroundContext() -> NSManagedObjectContext {
    return self.coreDataStack.backgroundContext
  }

  public func delete(_ item: NSManagedObject, context: NSManagedObjectContext) {
    context.delete(item)
    saveSyncContext(context)
  }

  public func delete(_ item: NSManagedObject) {
    delete(item, context: coreDataStack.managedContext)
  }
}
