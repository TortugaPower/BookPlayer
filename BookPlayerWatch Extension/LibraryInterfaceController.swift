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
    @IBOutlet weak var libraryTableView: WKInterfaceTable!
    @IBOutlet var spacerGroupView: WKInterfaceGroup!
    @IBOutlet weak var playlistTableView: WKInterfaceTable!

    var watchSession = WCSession.default

    var items = [LibraryItem]()
    var playlist = ["Part 1", "Part 2", "Part 3", "Part 4", "Part 5", "Part 4", "Part 5"]

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        watchSession.delegate = self
        watchSession.activate()
        self.setupTable()
    }

    func setupTable() {
        self.libraryTableView.setNumberOfRows(self.items.count, withRowType: "LibraryRow")
        print(self.items.count)

        if let book = self.items.first as? Book,
            let row = self.libraryTableView.rowController(at: 0) as? ItemRow {
            row.titleLabel.setText(book.title)
        }
        var index = 0
        for item in self.items {
            guard let row = self.libraryTableView.rowController(at: index) as? ItemRow else {
                continue
            }

            row.titleLabel.setText(item.title)
            index += 1
        }
        self.playlistTableView.setNumberOfRows(self.playlist.count, withRowType: "PlaylistRow")

        for (index, item) in self.playlist.enumerated() {
            guard let row = self.playlistTableView.rowController(at: index) as? ItemRow else {
                continue
            }

            row.titleLabel.setText(item)
        }
    }

    override func table(_ table: WKInterfaceTable, didSelectRowAt rowIndex: Int) {
        if table == self.playlistTableView || rowIndex == 0 {
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "derp"), object: nil)
            return
        }

        if table == self.libraryTableView {
            self.showPlaylist(true)
        }
    }

    @IBAction func collapsePlaylist() {
        self.showPlaylist(false)
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

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("========= derp: ", applicationContext)

        guard let data = applicationContext["library"] as? Data  else { return }

        let bgContext = DataManager.getBackgroundContext()
        let decoder = JSONDecoder()

        guard let context = CodingUserInfoKey.context else { return }

        decoder.userInfo[context] = bgContext

        guard let library = try? decoder.decode(Library.self, from: data),
            let items = library.items?.array as? [LibraryItem] else {
                print("==== merp")
                return
        }

        self.items = items

        self.setupTable()
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("======= received file: ", file)
    }
}

extension WKInterfaceController {
    func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: @escaping () -> Void) {
        animate(withDuration: duration, animations: animations)
        let derp = DispatchTime.now() + duration
        DispatchQueue.main.asyncAfter(deadline: derp, execute: completion)
    }
}
