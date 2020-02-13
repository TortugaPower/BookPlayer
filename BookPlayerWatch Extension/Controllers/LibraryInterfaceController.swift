//
//  LibraryInterfaceController.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 4/26/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import AVFoundation
import BookPlayerWatchKit
import Foundation
import WatchConnectivity
import WatchKit

enum ConnectionError: Error {
    case connectivityError
}

class LibraryInterfaceController: WKInterfaceController {
    @IBOutlet weak var separatorLastBookView: WKInterfaceSeparator!
    @IBOutlet var lastBookHeaderTitle: WKInterfaceLabel!
    @IBOutlet weak var lastBookTableView: WKInterfaceTable!
    @IBOutlet weak var separatorView: WKInterfaceSeparator!
    @IBOutlet weak var playlistHeader: WKInterfaceGroup!
    @IBOutlet var libraryHeaderTitle: WKInterfaceLabel!
    // Image credits for back image
    // Icon made by [Rami McMin](https://www.flaticon.com/authors/rami-mcmin)
    // from [Flaticon](https://www.flaticon.com/)
    @IBOutlet weak var backImage: WKInterfaceImage!
    @IBOutlet weak var libraryTableView: WKInterfaceTable!
    @IBOutlet var spacerGroupView: WKInterfaceGroup!
    @IBOutlet weak var playlistTableView: WKInterfaceTable!
    @IBOutlet weak var refreshButton: WKInterfaceButton!

    var library: Library!

    // TableView's datasource
    var items: [LibraryItem] {
        guard self.library != nil else {
            return []
        }

        return self.library.items?.array as? [LibraryItem] ?? []
    }

    var playlistItems: [Book]?

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        NotificationCenter.default.addObserver(self, selector: #selector(self.updateApplicationContext), name: .contextUpdate, object: nil)
        WatchConnectivityService.sharedManager.startSession()

        self.refreshButton.setTitle("watchapp_refresh_data_title".localized)
        self.lastBookHeaderTitle.setText("watchapp_last_played_title".localized)

        self.loadLibrary()

        self.setupLastBook()

        self.setupLibraryTable()
    }

    func loadLibrary(_ library: Library? = nil) {
        self.library = library ?? DataManager.loadLibrary()

        if let theme = self.library.currentTheme {
            self.lastBookHeaderTitle.setTextColor(theme.defaultAccentColor)
            self.separatorLastBookView.setColor(theme.defaultAccentColor)
            self.separatorView.setColor(theme.defaultAccentColor)
            self.backImage.setTintColor(theme.defaultAccentColor)
            self.libraryHeaderTitle.setTextColor(theme.defaultAccentColor)

            NotificationCenter.default.post(name: .theme, object: nil, userInfo: ["theme": theme])
        }
    }

    func play(_ book: Book) {
        let message: [String: AnyObject] = ["command": "play" as AnyObject,
                                            "identifier": book.identifier as AnyObject]

        do {
            try self.sendMessage(message)
        } catch {
            return
        }

        self.pushController(withName: "NowPlayingController", context: nil)
    }

    @objc func updateApplicationContext(_ notification: Notification) {
        guard
            let applicationContext = notification.userInfo as? [String: Any] else {
            return
        }

        let data = applicationContext["library"] as? Data

        if let rewindInterval = applicationContext["rewindInterval"] as? TimeInterval {
            UserDefaults.standard.set(rewindInterval, forKey: Constants.UserDefaults.rewindInterval.rawValue)
        }

        if let forwardInterval = applicationContext["forwardInterval"] as? TimeInterval {
            UserDefaults.standard.set(forwardInterval, forKey: Constants.UserDefaults.forwardInterval.rawValue)
        }

        guard let library = DataManager.decodeLibrary(data) else { return }

        self.loadLibrary(library)

        self.setupLastBook()

        self.setupLibraryTable()
    }

    // MARK: - TableView lifecycle

    func setupLastBook() {
        guard let book = self.library.lastPlayedBook else {
            self.hideLastBook(true)
            return
        }

        self.hideLastBook(false)

        self.lastBookTableView.setNumberOfRows(1, withRowType: "LibraryRow")

        NotificationCenter.default.post(name: .lastBook, object: nil, userInfo: ["book": book])

        guard let row = self.lastBookTableView.rowController(at: 0) as? ItemRow else { return }

        row.titleLabel.setText(book.title)
    }

    func hideLastBook(_ flag: Bool) {
        self.lastBookTableView.setHidden(flag)
        self.lastBookHeaderTitle.setHidden(flag)
        self.separatorLastBookView.setHidden(flag)
    }

    func setupLibraryTable() {
        self.refreshButton.setHidden(!self.items.isEmpty)
        self.libraryTableView.setNumberOfRows(self.items.count, withRowType: "LibraryRow")

        for (index, item) in self.items.enumerated() {
            guard let row = self.libraryTableView.rowController(at: index) as? ItemRow else {
                continue
            }

            row.titleLabel.setText(item.title)
            row.detailImage.setHidden(item is Book)
        }
    }

    func setupPlaylistTable() {
        guard let items = self.playlistItems else { return }

        self.playlistTableView.setNumberOfRows(items.count, withRowType: "PlaylistRow")

        for (index, item) in items.enumerated() {
            guard let row = self.playlistTableView.rowController(at: index) as? ItemRow else {
                continue
            }

            row.titleLabel.setText(item.title)
        }

        self.backImage.setHidden(false)
    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        if table == self.lastBookTableView {
            guard let book = self.library.lastPlayedBook else { return }
            self.play(book)
            return
        }

        if let items = self.playlistItems {
            let book = items[rowIndex]
            self.play(book)
            return
        }

        let item = self.items[rowIndex]

        guard let playlist = item as? Playlist,
            let books = playlist.books?.array as? [Book] else {
            // swiftlint:disable force_cast
            let book = item as! Book
            self.play(book)
            return
        }
        self.playlistItems = books
        self.libraryHeaderTitle.setText(playlist.title!)
        self.setupPlaylistTable()
        self.showPlaylist(true)
    }

    @IBAction func collapsePlaylist() {
        self.showPlaylist(false)
        self.backImage.setHidden(true)
        self.playlistItems = nil
        self.libraryHeaderTitle.setText("Library")
    }

    func showPlaylist(_ show: Bool) {
        let height: CGFloat = show ? 0.0 : 1.0

        if show {
            self.spacerGroupView.setRelativeHeight(1.0, withAdjustment: 0.0)
            self.playlistTableView.setHidden(false)
        }

        self.animate(withDuration: 0.3, animations: {
            self.spacerGroupView.setRelativeHeight(height, withAdjustment: 0.0) //height
            self.libraryTableView.setHidden(show) //flag
        }, completion: {
            if !show {
                self.playlistTableView.setHidden(true)
                self.spacerGroupView.setHeight(0.0)
            } else {
                self.scroll(to: self.playlistHeader, at: .top, animated: true)
            }
        })
    }

    @IBAction func refreshLibrary() {
        let message: [String: AnyObject] = ["command": "refresh" as AnyObject]

        try? self.sendMessage(message)
    }
}

extension WKInterfaceController {
    func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: @escaping () -> Void) {
        self.animate(withDuration: duration, animations: animations)
        let time = DispatchTime.now() + duration
        DispatchQueue.main.asyncAfter(deadline: time, execute: completion)
    }

    func sendMessage(_ message: [String: AnyObject]) throws {
        guard WatchConnectivityService.sharedManager.validReachableSession != nil else {
            let okAction = WKAlertAction(title: "Ok", style: .default) {}
            self.presentAlert(withTitle: "Connectivity Error", message: "There's a problem connecting to your phone, please try again later", preferredStyle: .alert, actions: [okAction])
            throw ConnectionError.connectivityError
        }

        WatchConnectivityService.sharedManager.sendMessage(message: message)
    }
}
