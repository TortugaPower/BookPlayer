//
//  ExtensionDelegate.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 4/25/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import RevenueCat
import SwiftUI
import WatchKit

class ExtensionDelegate: NSObject, WKApplicationDelegate, ObservableObject {
  static var contextManager = ContextManager()
  let databaseInitializer = DatabaseInitializer()
  @Published var coreServices: CoreServices?

  /// Reference to the task that creates the core services
  var setupCoreServicesTask: Task<(), Error>?
  var errorCoreServicesSetup: Error?

  func applicationDidFinishLaunching() {
    setupRevenueCat()
    setupCoreServices()
  }

  func setupRevenueCat() {
    let revenueCatApiKey: String = Bundle.main.configurationValue(
      for: .revenueCat
    )
    Purchases.logLevel = .error
    let rcUserId = UserDefaults.standard.string(forKey: "rcUserId")
    Purchases.configure(withAPIKey: revenueCatApiKey, appUserID: rcUserId)
    Purchases.shared.delegate = self
  }

  func setupCoreServices() {
    setupCoreServicesTask = Task {
      do {
        let stack = try await databaseInitializer.loadCoreDataStack()
        let coreServices = createCoreServicesIfNeeded(from: stack)
        self.coreServices = coreServices
        /// setup blank account if needed
        guard !coreServices.accountService.hasAccount() else { return }
        coreServices.accountService.createAccount(donationMade: false)
      } catch {
        errorCoreServicesSetup = error
      }
    }
  }

  func createCoreServicesIfNeeded(from stack: CoreDataStack) -> CoreServices {
    if let coreServices = self.coreServices {
      return coreServices
    } else {
      let dataManager = DataManager(coreDataStack: stack)
      let accountService = AccountService(dataManager: dataManager)
      let libraryService = LibraryService(dataManager: dataManager)
      let syncService = SyncService(
        isActive: accountService.hasSyncEnabled(),
        libraryService: libraryService
      )
      let playbackService = PlaybackService(libraryService: libraryService)
      let coreServices = CoreServices(
        dataManager: dataManager,
        accountService: accountService,
        syncService: syncService,
        libraryService: libraryService,
        playbackService: playbackService
      )

      self.coreServices = coreServices

      return coreServices
    }
  }

  /// For some reason this never gets called
  func handleRemoteNowPlayingActivity() {}

  func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
    // Sent when the system needs to launch the application in the background to process tasks. Tasks arrive in a set, so loop through and process each one.
    for task in backgroundTasks {
      // Use a switch statement to check the task type
      switch task {
      case let backgroundTask as WKApplicationRefreshBackgroundTask:
        // Be sure to complete the background task once you’re done.
        backgroundTask.setTaskCompletedWithSnapshot(false)
      case let snapshotTask as WKSnapshotRefreshBackgroundTask:
        // Snapshot tasks have a unique completion call, make sure to set your expiration date
        snapshotTask.setTaskCompleted(
          restoredDefaultState: true,
          estimatedSnapshotExpiration: Date.distantFuture,
          userInfo: nil
        )
      case let connectivityTask as WKWatchConnectivityRefreshBackgroundTask:
        // Be sure to complete the connectivity task once you’re done.
        connectivityTask.setTaskCompletedWithSnapshot(false)
      case let urlSessionTask as WKURLSessionRefreshBackgroundTask:
        // Be sure to complete the URL session task once you’re done.
        urlSessionTask.setTaskCompletedWithSnapshot(false)
      case let relevantShortcutTask as WKRelevantShortcutRefreshBackgroundTask:
        // Be sure to complete the relevant-shortcut task once you're done.
        relevantShortcutTask.setTaskCompletedWithSnapshot(false)
      case let intentDidRunTask as WKIntentDidRunRefreshBackgroundTask:
        // Be sure to complete the intent-did-run task once you're done.
        intentDidRunTask.setTaskCompletedWithSnapshot(false)
      default:
        // make sure to complete unhandled task types
        task.setTaskCompletedWithSnapshot(false)
      }
    }
  }
}

extension ExtensionDelegate: PurchasesDelegate {
  func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
    coreServices?.hasSyncEnabled = customerInfo.entitlements.all["pro"]?.isActive == true
  }
}
