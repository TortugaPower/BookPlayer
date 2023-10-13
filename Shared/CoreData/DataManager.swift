//
//  DataManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/3/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import CoreData
import Foundation

public class DataManager {
  public static let processedFolderName = "Processed"
  public static let backupFolderName = "BPBackup"
  public static let inboxFolderName = "Inbox"
  public static let sharedFolderName = "SharedBP"
  public static var loadingDataError: Error?
  private let coreDataStack: CoreDataStack
  private var pendingSaveContext: DispatchWorkItem?

  public init(coreDataStack: CoreDataStack) {
    self.coreDataStack = coreDataStack
  }
  // MARK: - Folder URLs

  public class func getDocumentsFolderURL() -> URL {
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  }

  public class func getProcessedFolderURL() -> URL {
    let documentsURL = self.getDocumentsFolderURL()

    let processedFolderURL = documentsURL.appendingPathComponent(self.processedFolderName)

    if !FileManager.default.fileExists(atPath: processedFolderURL.path) {
      do {
        try FileManager.default.createDirectory(at: processedFolderURL, withIntermediateDirectories: true, attributes: nil)
      } catch {
        fatalError("Couldn't create Processed folder")
      }
    }

    return processedFolderURL
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
    return self.coreDataStack.getBackgroundContext()
  }

  public func delete(_ item: NSManagedObject, context: NSManagedObjectContext) {
    context.delete(item)
    saveSyncContext(context)
  }

  public func delete(_ item: NSManagedObject) {
    delete(item, context: coreDataStack.managedContext)
  }
}
