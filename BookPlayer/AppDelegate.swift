//
// AppDelegate.swift
// BookPlayer
//
// Created by Gianni Carlo on 7/1/16.
// Copyright © 2016 Tortuga Power. All rights reserved.
//

import AVFoundation
import DirectoryWatcher
import MediaPlayer
import Sentry
import SwiftyStoreKit
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var wasPlayingBeforeInterruption: Bool = false
    var watcher: DirectoryWatcher?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let defaults: UserDefaults = UserDefaults.standard

        // Perfrom first launch setup
        if !defaults.bool(forKey: Constants.UserDefaults.completedFirstLaunch.rawValue) {
            // Set default settings
            defaults.set(true, forKey: Constants.UserDefaults.chapterContextEnabled.rawValue)
            defaults.set(true, forKey: Constants.UserDefaults.smartRewindEnabled.rawValue)
            defaults.set(true, forKey: Constants.UserDefaults.completedFirstLaunch.rawValue)
        }

        // Appearance
        UINavigationBar.appearance().titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: UIColor(hex: "#37454E")
        ]

        if #available(iOS 11, *) {
            UINavigationBar.appearance().largeTitleTextAttributes = [
                NSAttributedString.Key.foregroundColor: UIColor(hex: "#37454E")
            ]
        }

        try? AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode(rawValue: convertFromAVAudioSessionMode(AVAudioSession.Mode.spokenAudio)), options: [])

        // register to audio-interruption notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleAudioInterruptions(_:)), name: AVAudioSession.interruptionNotification, object: nil)

        // register to audio-route-change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleAudioRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)

        // register for remote events
        self.setupMPRemoteCommands()
        // register document's folder listener
        self.setupDocumentListener()
        // load themes if necessary
        DataManager.setupDefaultTheme()
        // setup store required listeners
        self.setupStoreListener()

        if let activityDictionary = launchOptions?[.userActivityDictionary] as? [UIApplication.LaunchOptionsKey: Any],
            let activityType = activityDictionary[.userActivityType] as? String,
            activityType == Constants.UserActivityPlayback {
            defaults.set(true, forKey: activityType)
        }

        // Create a Sentry client and start crash handler
        Client.shared = try? Client(dsn: "https://23b4d02f7b044c10adb55a0cc8de3881@sentry.io/1414296")
        ((try? Client.shared?.startCrashHandler()) as ()??)

        return true
    }

    // Handles audio file urls, like when receiving files through AirDrop
    // Also handles custom URL scheme 'bookplayer://'
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        guard url.isFileURL else {
            self.playLastBook()
            return true
        }

        DataManager.processFile(at: url)

        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        self.playLastBook()
        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.

        DispatchQueue.main.async {
            if !PlayerManager.shared.isPlaying {
                NotificationCenter.default.post(name: .bookPaused, object: nil)
            }
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        // Check if the app is on the PlayerViewController
        // TODO: Check if this still works as expected given the new storyboard structure
        guard let navigationVC = UIApplication.shared.keyWindow?.rootViewController!, navigationVC.children.count > 1 else {
            return
        }

        // Notify controller to see if it should ask for review
        NotificationCenter.default.post(name: .requestReview, object: nil)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        self.playLastBook()
    }

    func playLastBook() {
        if PlayerManager.shared.hasLoadedBook {
            PlayerManager.shared.play()
        } else {
            UserDefaults.standard.set(true, forKey: Constants.UserActivityPlayback)
        }
    }

    // Playback may be interrupted by calls. Handle pause
    @objc func handleAudioInterruptions(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }

        switch type {
        case .began:
            if PlayerManager.shared.isPlaying {
                PlayerManager.shared.pause()
            }
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt else {
                return
            }

            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                PlayerManager.shared.play()
            }
            @unknown default:
            break
        }
    }

    // Handle audio route changes
    @objc func handleAudioRouteChange(_ notification: Notification) {
        guard PlayerManager.shared.isPlaying,
            let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        // Pause playback if route changes due to a disconnect
        switch reason {
        case .oldDeviceUnavailable:
            guard let storedPort = PlayerManager.shared.outputPort,
                let currentRoute = AVAudioSession.sharedInstance().currentRoute.outputs.first else { return }

            guard storedPort != currentRoute else { return }

            guard currentRoute.portType == .builtInSpeaker else { return }

            DispatchQueue.main.async {
                PlayerManager.shared.pause()
            }
        default:
            break
        }
    }

    // For now, seek forward/backward and next/previous track perform the same function
    func setupMPRemoteCommands() {
        // Play / Pause
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled = true
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayerManager.shared.playPause()
            return .success
        }

        MPRemoteCommandCenter.shared().playCommand.isEnabled = true
        MPRemoteCommandCenter.shared().playCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayerManager.shared.play()
            return .success
        }

        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = true
        MPRemoteCommandCenter.shared().pauseCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayerManager.shared.pause()
            return .success
        }

        // Forward
        MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [NSNumber(value: PlayerManager.shared.forwardInterval)]

        MPRemoteCommandCenter.shared().skipForwardCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayerManager.shared.forward()
            return .success
        }

        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayerManager.shared.forward()
            return .success
        }

        MPRemoteCommandCenter.shared().seekForwardCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
            guard let cmd = commandEvent as? MPSeekCommandEvent, cmd.type == .endSeeking else {
                return .success
            }

            // End seeking
            PlayerManager.shared.forward()
            return .success
        }

        // Rewind
        MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [NSNumber(value: PlayerManager.shared.rewindInterval)]

        MPRemoteCommandCenter.shared().skipBackwardCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayerManager.shared.rewind()
            return .success
        }

        MPRemoteCommandCenter.shared().previousTrackCommand.addTarget { (_) -> MPRemoteCommandHandlerStatus in
            PlayerManager.shared.rewind()
            return .success
        }

        MPRemoteCommandCenter.shared().seekBackwardCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
            guard let cmd = commandEvent as? MPSeekCommandEvent, cmd.type == .endSeeking else {
                return .success
            }

            // End seeking
            PlayerManager.shared.rewind()
            return .success
        }
    }

    func setupDocumentListener() {
        let documentsUrl = DataManager.getDocumentsFolderURL()
        self.watcher = DirectoryWatcher.watch(documentsUrl)
        self.watcher?.ignoreDirectories = false
        self.watcher?.onNewFiles = { newFiles in
            for url in newFiles {
                DataManager.processFile(at: url)
            }
        }
    }

    func setupStoreListener() {
        SwiftyStoreKit.completeTransactions(atomically: true) { purchases in
            for purchase in purchases {
                guard purchase.transaction.transactionState == .purchased
                    || purchase.transaction.transactionState == .restored
                else { continue }

                UserDefaults.standard.set(true, forKey: Constants.UserDefaults.donationMade.rawValue)
                NotificationCenter.default.post(name: .donationMade, object: nil)

                if purchase.needsFinishTransaction {
                    SwiftyStoreKit.finishTransaction(purchase.transaction)
                }
            }
        }

        SwiftyStoreKit.shouldAddStorePaymentHandler = { _, _ in
            true
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionMode(_ input: AVAudioSession.Mode) -> String {
    return input.rawValue
}
