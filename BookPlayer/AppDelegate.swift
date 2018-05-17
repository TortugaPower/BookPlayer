//
// AppDelegate.swift
// BookPlayer
//
// Created by Gianni Carlo on 7/1/16.
// Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import AVFoundation
import Fabric
import Crashlytics
import MediaPlayer

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        Fabric.with([Crashlytics.self])

        let defaults: UserDefaults = UserDefaults.standard

        // Perfrom first launch setup
        if !defaults.bool(forKey: UserDefaultsConstants.completedFirstLaunch) {
            // Set default settings
            defaults.set(true, forKey: UserDefaultsConstants.smartRewindEnabled)
            defaults.set(true, forKey: UserDefaultsConstants.completedFirstLaunch)
        }

        // Appearance
        UINavigationBar.appearance().titleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.init(hex: "#37454E")]

        if #available(iOS 11, *) {
            UINavigationBar.appearance().largeTitleTextAttributes = [NSAttributedStringKey.foregroundColor: UIColor.init(hex: "#37454E")]
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
        } catch {
            // @TODO: Handle failing AVAudioSession
        }

        // register to audio-interruption notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleAudioInterruptions(_:)), name: NSNotification.Name.AVAudioSessionInterruption, object: nil)

        // register to audio-route-change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.handleAudioRouteChange(_:)), name: NSNotification.Name.AVAudioSessionRouteChange, object: nil)

        // register for remote events
        self.registerRemoteEvents()

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey: Any] = [:]) -> Bool {
        // This function is called when the app is opened with a audio file url,
        // like when receiving files through AirDrop

        let fmanager = FileManager.default
        let filename = url.lastPathComponent
        let documentsURL = fmanager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsURL.appendingPathComponent(filename)

        // move file from Inbox to Document folder
        do {
            try fmanager.moveItem(at: url, to: destinationURL)
            // In case the app was already running in background
            let userInfo = ["fileURL": destinationURL]
            NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.openURL, object: nil, userInfo: userInfo)
        } catch {
            do {
                try fmanager.removeItem(at: url)
            } catch {
                // @TODO: How should this case be handled?
            }

            return false
        }

        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.

        // Check if the app is on the PlayerViewController
        guard let navigationVC = UIApplication.shared.keyWindow?.rootViewController!,
            navigationVC.childViewControllers.count > 1 else {

            return
        }

        // Notify controller to see if it should ask for review
        NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.requestReview, object: nil)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    // Playback may be interrupted by calls. Handle pause
    @objc func handleAudioInterruptions(_ notification: Notification) {
        if PlayerManager.shared.isPlaying {
            PlayerManager.shared.pause()
        }
    }

    // Handle audio route changes
    @objc func handleAudioRouteChange(_ notification: Notification) {
        guard PlayerManager.shared.isPlaying,
            let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            let reason = AVAudioSessionRouteChangeReason(rawValue: reasonValue) else {
                return
        }

        // Pause playback if route changes due to a disconnect
        switch reason {
        case .oldDeviceUnavailable:
            PlayerManager.shared.play()
        default:
            break
        }
    }

    // For now, seek forward/backward and next/previous track perform the same function
    func registerRemoteEvents() {
        let togglePlayPauseHandler: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { (_) -> MPRemoteCommandHandlerStatus in
            PlayerManager.shared.playPause()
            return .success
        }

        MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled = true
        MPRemoteCommandCenter.shared().togglePlayPauseCommand.addTarget(handler: togglePlayPauseHandler)

        MPRemoteCommandCenter.shared().playCommand.isEnabled = true
        MPRemoteCommandCenter.shared().playCommand.addTarget(handler: togglePlayPauseHandler)

        MPRemoteCommandCenter.shared().pauseCommand.isEnabled = true
        MPRemoteCommandCenter.shared().pauseCommand.addTarget(handler: togglePlayPauseHandler)

        let skipForwardHandler: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { (commandEvent) -> MPRemoteCommandHandlerStatus in
            PlayerManager.shared.forward()
            return .success
        }

        MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [PlayerManager.shared.forwardInterval] as [NSNumber]
        MPRemoteCommandCenter.shared().skipForwardCommand.addTarget(handler: skipForwardHandler)

        MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [PlayerManager.shared.rewindInterval] as [NSNumber]
        MPRemoteCommandCenter.shared().nextTrackCommand.addTarget(handler: skipForwardHandler)

        MPRemoteCommandCenter.shared().seekForwardCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
            guard let cmd = commandEvent as? MPSeekCommandEvent, cmd.type == .endSeeking else {
                return .success
            }

            // End seeking
            PlayerManager.shared.forward()

            return .success
        }

        let skipBackwardHandler: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { (commandEvent) -> MPRemoteCommandHandlerStatus in
            PlayerManager.shared.rewind()

            return .success
        }

        MPRemoteCommandCenter.shared().skipBackwardCommand.addTarget(handler: skipBackwardHandler)
        MPRemoteCommandCenter.shared().previousTrackCommand.addTarget(handler: skipBackwardHandler)

        MPRemoteCommandCenter.shared().seekBackwardCommand.addTarget { (commandEvent) -> MPRemoteCommandHandlerStatus in
            guard let cmd = commandEvent as? MPSeekCommandEvent,
                cmd.type == .endSeeking else { return .success }

            //end seeking
            PlayerManager.shared.rewind()
            return .success
        }
    }
}
