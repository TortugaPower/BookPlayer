//
//  ActionParserService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import Intents
import TelemetryClient

class ActionParserService {
    public class func process(_ url: URL) {
        guard let action = CommandParser.parse(url) else { return }

        self.handleAction(action)
    }

    public class func process(_ activity: NSUserActivity) {
        guard let action = CommandParser.parse(activity) else { return }

        self.handleAction(action)
    }

    public class func process(_ intent: INIntent) {
        guard let action = CommandParser.parse(intent) else { return }

        self.handleAction(action)
    }

    public class func handleAction(_ action: Action) {
        switch action.command {
        case .play:
            self.handlePlayAction(action)
        case .download:
            self.handleDownloadAction(action)
        case .sleep:
            self.handleSleepAction(action)
        case .refresh:
            WatchConnectivityService.sharedManager.sendApplicationContext()
        case .skipRewind:
            PlayerManager.shared.rewind()
        case .skipForward:
            PlayerManager.shared.forward()
        case .widget:
            self.handleWidgetAction(action)
        }

        // avoid registering actions not (necessarily) initiated by the user
        if action.command != .refresh {
            TelemetryManager.shared.send(TelemetrySignal.urlSchemeAction.rawValue, with: action.getParametersDictionary())
        }
    }

    private class func handleSleepAction(_ action: Action) {
        guard let value = action.getQueryValue(for: "seconds"),
            let seconds = Double(value) else {
            return
        }

        switch seconds {
        case -1:
            SleepTimer.shared.reset()
        case -2:
            SleepTimer.shared.sleep(in: .endChapter)
        default:
            SleepTimer.shared.sleep(in: seconds)
        }
    }

    private class func handlePlayAction(_ action: Action) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else { return }

        if let value = action.getQueryValue(for: "showPlayer"),
            let showPlayer = Bool(value),
            showPlayer {
            appDelegate.showPlayer()
        }

        if let value = action.getQueryValue(for: "autoplay"),
            let autoplay = Bool(value),
            !autoplay {
            return
        }

        guard let bookIdentifier = action.getQueryValue(for: "identifier") else {
            appDelegate.playLastBook()
            return
        }

        if let loadedBook = PlayerManager.shared.currentBook, loadedBook.identifier == bookIdentifier {
            PlayerManager.shared.play()
            return
        }

        guard let library = try? DataManager.getLibrary(),
              let book = DataManager.getBook(with: bookIdentifier, from: library) else { return }

        guard let libraryVC = appDelegate.getLibraryVC() else {
            return
        }

        libraryVC.setupPlayer(book: book)
        NotificationCenter.default.post(name: .bookChange,
                                        object: nil,
                                        userInfo: ["book": book])
    }

    private class func handleDownloadAction(_ action: Action) {
        guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            let libraryVC = appDelegate.getLibraryVC() else {
            return
        }

        libraryVC.navigationController?.dismiss(animated: true, completion: nil)

        if let url = action.getQueryValue(for: "url")?.replacingOccurrences(of: "\"", with: "") {
            libraryVC.downloadBook(from: url)
        }
    }

    private class func handleWidgetAction(_ action: Action) {
        if action.getQueryValue(for: "autoplay") != nil {
            let playAction = Action(command: .play, parameters: action.parameters)
            self.handleAction(playAction)
        }

        if action.getQueryValue(for: "seconds") != nil {
            let sleepAction = Action(command: .sleep, parameters: action.parameters)
            self.handleAction(sleepAction)
        }
    }
}
