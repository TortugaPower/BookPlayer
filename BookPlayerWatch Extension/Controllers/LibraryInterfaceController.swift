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

        WatchConnectivityService.sharedManager.startSession(self)

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
        }
    }

    func play(_ book: Book) {
        guard WatchConnectivityService.sharedManager.validReachableSession != nil else {
            let okAction = WKAlertAction(title: "Ok", style: .default) {}
            self.presentAlert(withTitle: "Connectivity Error", message: "There's a problem connecting to your phone, please try again later", preferredStyle: .alert, actions: [okAction])
            return
        }

        let message: [String: AnyObject] = ["command": "play" as AnyObject,
                                            "identifier": book.identifier as AnyObject]

        WatchConnectivityService.sharedManager.sendMessage(message: message)

        NotificationCenter.default.post(name: .bookPlayed, object: nil)
    }

    // MARK: - TableView lifecycle

    func setupLastBook() {
        guard let book = self.library.lastPlayedBook else {
            self.lastBookTableView.setHidden(true)
            self.lastBookHeaderTitle.setHidden(true)
            return
        }

        self.lastBookTableView.setHidden(false)
        self.lastBookHeaderTitle.setHidden(false)

        self.lastBookTableView.setNumberOfRows(1, withRowType: "LibraryRow")

        guard let row = self.lastBookTableView.rowController(at: 0) as? ItemRow else { return }

        row.titleLabel.setText(book.title)
    }

    func setupLibraryTable() {
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
        self.scroll(to: self.playlistHeader, at: .top, animated: true)
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
            }
        })
    }
}

extension WKInterfaceController {
    func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: @escaping () -> Void) {
        self.animate(withDuration: duration, animations: animations)
        let time = DispatchTime.now() + duration
        DispatchQueue.main.asyncAfter(deadline: time, execute: completion)
    }
}

// MARK: - WCSessionDelegate

extension LibraryInterfaceController: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // For some reason, the first message is always lost
        WatchConnectivityService.sharedManager.sendMessage(message: [:])
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext["library"] as? Data

        guard let library = DataManager.decodeLibrary(data) else { return }

        self.loadLibrary(library)

        self.setupLastBook()

        self.setupLibraryTable()
    }
}
