//
//  PlaylistViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class PlaylistViewController: BaseListViewController {
    override var items: [LibraryItem] {
        return self.playlist.books?.array as? [LibraryItem] ?? []
    }
    var playlist: Playlist!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationItem.title = playlist.title
    }

    override func loadFiles() {

    }
}

extension PlaylistViewController {
    override func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard destinationIndexPath.section == 0 else {
            return
        }

        // swiftlint:disable force_cast
        let book = self.items[sourceIndexPath.row] as! Book
        self.playlist.removeFromBooks(at: sourceIndexPath.row)
        self.playlist.insertIntoBooks(book, at: destinationIndexPath.row)
        DataManager.saveContext()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section == 0 else {
            self.presentImportFilesAlert()
            return
        }

        let item = self.items[indexPath.row]

        guard let book = item as? Book else {
            return
        }

        self.setupPlayer(book: book)
    }
}
