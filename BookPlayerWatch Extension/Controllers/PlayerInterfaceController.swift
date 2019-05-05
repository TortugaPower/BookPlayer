//
//  PlayerInterfaceController.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 4/26/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import WatchKit

class PlayerInterfaceController: WKInterfaceController {
    @IBOutlet weak var titleLabel: WKInterfaceLabel!
    @IBOutlet weak var authorLabel: WKInterfaceLabel!
    @IBOutlet weak var rewindButton: WKInterfaceButton!
    @IBOutlet weak var rewindLabel: WKInterfaceLabel!
    @IBOutlet weak var forwardButton: WKInterfaceButton!
    @IBOutlet weak var forwardLabel: WKInterfaceLabel!
    @IBOutlet weak var playButton: WKInterfaceButton!
    @IBOutlet weak var playImage: WKInterfaceImage!
    @IBOutlet weak var pauseImage: WKInterfaceImage!
    @IBOutlet weak var volumeControl: WKInterfaceVolumeControl!

    var lastBook: Book? {
        didSet {
            let title = self.lastBook?.title ?? ""
            let author = self.lastBook?.author ?? ""
            self.titleLabel.setText(title)
            self.authorLabel.setText(author)
        }
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        NotificationCenter.default.addObserver(self, selector: #selector(self.bookPlayedNotification), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.lastBookNotification(_:)), name: .lastBook, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.messageReceived), name: .messageReceived, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.themeNotification), name: .theme, object: nil)

        let library = DataManager.loadLibrary()

        if let book = library.lastPlayedBook {
            self.lastBook = book
        }

        if let theme = library.currentTheme {
            self.volumeControl.setTintColor(theme.highlightColor)
        }

        self.setSkipLabels()
    }

    @objc func bookPlayedNotification() {
        super.becomeCurrentPage()
    }

    @objc func lastBookNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
            let book = userInfo["book"] as? Book else {
            return
        }

        self.lastBook = book
    }

    @objc func themeNotification(_ notification: Notification) {
        guard let userInfo = notification.userInfo as? [String: Any],
            let theme = userInfo["theme"] as? Theme else {
            return
        }

        self.volumeControl.setTintColor(theme.highlightColor)
    }

    func setSkipLabels() {
        let rewind = UserDefaults.standard.integer(forKey: Constants.UserDefaults.rewindInterval.rawValue)
        let forward = UserDefaults.standard.integer(forKey: Constants.UserDefaults.forwardInterval.rawValue)
        if rewind > 0 {
            self.rewindLabel.setText("-\(rewind)")
        }

        if forward > 0 {
            self.forwardLabel.setText("\(forward)")
        }
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

        self.setSkipLabels()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    @IBAction func skipBack() {
        let message: [String: AnyObject] = ["command": "skipRewind" as AnyObject]

        try? self.sendMessage(message)

        self.rewindButton.setAlpha(0.5)

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            self.animate(withDuration: 0.3) {
                self.rewindButton.setAlpha(1)
            }
        }
    }

    @IBAction func skipForward() {
        let message: [String: AnyObject] = ["command": "skipForward" as AnyObject]

        try? self.sendMessage(message)

        self.forwardButton.setAlpha(0.5)

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.1) {
            self.animate(withDuration: 0.3) {
                self.forwardButton.setAlpha(1)
            }
        }
    }

    // Image credits for play image
    // Icon made by [Egor Rumyantsev](https://www.flaticon.com/authors/egor-rumyantsev)
    // from [Flaticon](https://www.flaticon.com/)
    // Image credits for pause image
    // Icon made by [Egor Rumyantsev](https://www.flaticon.com/authors/egor-rumyantsev)
    // from [Flaticon](https://www.flaticon.com/)
    @IBAction func playPausePressed() {
        guard let book = self.lastBook else { return }

        let message: [String: AnyObject] = ["command": "playPause" as AnyObject,
                                            "identifier": book.identifier as AnyObject]

        try? self.sendMessage(message)

        self.playButton.setAlpha(0.5)

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.3) {
            self.animate(withDuration: 0.3) {
                self.playButton.setAlpha(1)
            }
        }
    }

    @objc func messageReceived(_ notification: Notification) {
        guard
            let message = notification.userInfo as? [String: Any] else {
            return
        }

        DispatchQueue.main.async {
            guard let command = message["notification"] as? String else { return }

            if command == "bookPlayed" {
                self.playImage.setHidden(true)
                self.pauseImage.setHidden(false)
                return
            }

            if command == "bookPaused" {
                self.playImage.setHidden(false)
                self.pauseImage.setHidden(true)
                return
            }
        }
    }
}
