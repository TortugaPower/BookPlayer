//
//  InterfaceController.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 9/20/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import WatchKit
import Foundation
import BookPlayerKitWatch
import AVFoundation
import WatchConnectivity

class LibraryInterfaceController: WKInterfaceController {
    @IBOutlet weak var playlistHeader: WKInterfaceGroup!
    @IBOutlet var playlistHeaderTitle: WKInterfaceLabel!
    @IBOutlet weak var libraryTableView: WKInterfaceTable!
    @IBOutlet var spacerGroupView: WKInterfaceGroup!
    @IBOutlet weak var playlistTableView: WKInterfaceTable!

    var watchSession = WCSession.default

    var library: Library!

    // TableView's datasource
    var items: [LibraryItem] {
        guard self.library != nil else {
            return []
        }

        return self.library.items?.array as? [LibraryItem] ?? []
    }

    var playlistItems = [Book]()

    var dataUrl: URL {
        let documentsFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let filename = "library.data"
        return documentsFolder.appendingPathComponent(filename)
    }

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        self.library = DataManager.getLibrary()

        if let library = self.decodeLibrary(FileManager.default.contents(atPath: self.dataUrl.path)) {
            self.library = library
        }

        watchSession.delegate = self
        watchSession.activate()

        self.setupLibraryTable()
    }

    func setupLibraryTable() {
        self.libraryTableView.setNumberOfRows(self.items.count, withRowType: "LibraryRow")

        for (index, item) in self.items.enumerated() {
            guard let row = self.libraryTableView.rowController(at: index) as? ItemRow else {
                continue
            }

            row.titleLabel.setText(item.title)
        }
    }

    func setupPlaylistTable() {
        self.playlistTableView.setNumberOfRows(self.playlistItems.count, withRowType: "PlaylistRow")

        for (index, item) in self.playlistItems.enumerated() {
            guard let row = self.playlistTableView.rowController(at: index) as? ItemRow else {
                continue
            }

            row.titleLabel.setText(item.title)
        }
    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        let item = self.items[rowIndex]

        guard let playlist = item as? Playlist,
            let books = playlist.books?.array as? [Book] else {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "derp"), object: nil)
            return
        }
        self.playlistItems = books
        self.playlistHeaderTitle.setText("< \(playlist.title!)")
        self.setupPlaylistTable()
        self.showPlaylist(true)
    }

    @IBAction func collapsePlaylist() {
        self.showPlaylist(false)
        self.playlistItems = []
    }

    func showPlaylist(_ show: Bool) {
        let title = show
            ? "Playlist"
            : "Library"

        self.setTitle(title)

        let height: CGFloat = show ? 0.0 : 1.0

        if show {
            self.spacerGroupView.setRelativeHeight(1.0, withAdjustment: 0.0)
            self.playlistTableView.setHidden(false)
        }

        self.animate(withDuration: 0.3, animations: {
            self.playlistHeader.setHidden(!show)//!flag
            self.spacerGroupView.setRelativeHeight(height, withAdjustment: 0.0)//height
            self.libraryTableView.setHidden(show)//flag
        }) {
            if !show {
                self.playlistTableView.setHidden(true)
                self.spacerGroupView.setHeight(0.0)
            }
        }
    }
}

extension LibraryInterfaceController: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Session activation did complete")
        //query phone
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let data = applicationContext["library"] as? Data
        guard let library = self.decodeLibrary(data) else { return }

        try? data?.write(to: self.dataUrl)

        self.library = library

        self.setupLibraryTable()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("======= received file: ", file)
    }

    func decodeLibrary(_ data: Data?) -> Library? {
        guard let data = data  else { return nil }

        let bgContext = DataManager.getBackgroundContext()
        let decoder = JSONDecoder()

        guard let context = CodingUserInfoKey.context else { return nil }

        decoder.userInfo[context] = bgContext

        guard let library = try? decoder.decode(Library.self, from: data) else {
            return nil
        }

        return library
    }
}

extension WKInterfaceController {
    func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: @escaping () -> Void) {
        animate(withDuration: duration, animations: animations)
        let derp = DispatchTime.now() + duration
        DispatchQueue.main.asyncAfter(deadline: derp, execute: completion)
    }
}
