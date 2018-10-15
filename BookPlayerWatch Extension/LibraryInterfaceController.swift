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

class LibraryInterfaceController: WKInterfaceController {
    @IBOutlet weak var playlistHeader: WKInterfaceGroup!
    @IBOutlet weak var libraryTableView: WKInterfaceTable!
    @IBOutlet var spacerGroupView: WKInterfaceGroup!
    @IBOutlet weak var playlistTableView: WKInterfaceTable!

    var items = ["Neverwhere", "D.O.D.O", "a", "a", "a", "a", "a"]
    var playlist = ["Part 1", "Part 2", "Part 3", "Part 4", "Part 5", "Part 4", "Part 5"]

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        self.setupTable()
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    func setupTable() {
        self.libraryTableView.setNumberOfRows(self.items.count, withRowType: "LibraryRow")

        for (index, item) in self.items.enumerated() {
            guard let row = self.libraryTableView.rowController(at: index) as? ItemRow else {
                continue
            }

            row.titleLabel.setText(item)
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

extension WKInterfaceController {
    func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: @escaping () -> Void) {
        animate(withDuration: duration, animations: animations)
        let derp = DispatchTime.now() + duration
        DispatchQueue.main.asyncAfter(deadline: derp, execute: completion)
    }
}
