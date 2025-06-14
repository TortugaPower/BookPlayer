//
//  SceneDelegate.swift
//  BookPlayer
//
//  Created by gianni.carlo on 25/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import AVFoundation
import BookPlayerKit
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  /// Hold strong reference
  var startingNavigationController = UINavigationController()
  lazy var coordinator = LoadingCoordinator(
    flow: .pushFlow(navigationController: startingNavigationController)
  )

  var mainCoordinator: MainCoordinator? {
    coordinator.getMainCoordinator()
  }

  func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
    if let activityType = connectionOptions.userActivities.first?.activityType,
       activityType == Constants.UserActivityPlayback {
      playLastBook()
    }

    handleOpening(URLContexts: connectionOptions.urlContexts)

    guard let windowScene = (scene as? UIWindowScene) else { return }

    let appWindow = UIWindow(frame: windowScene.coordinateSpace.bounds)
    appWindow.windowScene = windowScene

    coordinator.start()

    appWindow.rootViewController = startingNavigationController
    appWindow.makeKeyAndVisible()

    window = appWindow
  }

  // Handles audio file urls, like when receiving files through AirDrop
  // Also handles custom URL scheme 'bookplayer://'
  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    handleOpening(URLContexts: URLContexts)
  }

  func handleOpening(URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
      ActionParserService.process(context.url)
    }
  }

  func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
    playLastBook()
    completionHandler(true)
  }

  func sceneWillResignActive(_ scene: UIScene) {
    /// Store last delegate to be active (when airdropping, all scenes resign active)
    AppDelegate.shared?.lastSceneToResignActive = self
  }

  func sceneDidBecomeActive(_ scene: UIScene) {
    guard
      let mainCoordinator
    else {
      return
    }

    // Check if the app is on the PlayerViewController
    if mainCoordinator.hasPlayerShown() {
      // Notify controller to see if it should ask for review
      NotificationCenter.default.post(name: .requestReview, object: nil)
    }

    if let libraryCoordinator = mainCoordinator.getLibraryCoordinator() {
      /// Sync list when app is active again
      libraryCoordinator.syncList()
      /// Sync currently shown list
      libraryCoordinator.syncLastFolderList()
      /// Register import observer in case it's not up already
      libraryCoordinator.bindImportObserverIfNeeded()
    }
  }

  func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    ActionParserService.process(userActivity)
  }
}

extension SceneDelegate {
  func playLastBook() {
    AppDelegate.shared?.playLastBook()
  }
}
