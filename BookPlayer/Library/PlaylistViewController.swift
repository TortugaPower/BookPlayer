//
//  PlaylistViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import MBProgressHUD

class PlaylistViewController: BaseListViewController {
    @IBOutlet private weak var emptyPlaylistPlaceholder: UIView!

    var playlist: Playlist!

    override var items: [LibraryItem] {
        return self.playlist.books?.array as? [LibraryItem] ?? []
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if !self.items.isEmpty {
            self.emptyPlaylistPlaceholder.isHidden = true
        }

        self.navigationItem.title = playlist.title
    }

    override func loadFile(urls: [URL]) {
        DataManager.insertBooks(from: urls, into: self.playlist) {
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.bookDeleted, object: nil)
            self.tableView.reloadData()
        }
    }

    @IBAction func addAction() {
        self.presentImportFilesAlert()
    }

    @objc override func onBookPlay() {
        guard let index = self.playlist.itemIndex(with: PlayerManager.shared.currentBook.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BookCellView else {
                return
        }

        bookCell.artworkButton.setImage(#imageLiteral(resourceName: "playerIconPlay"), for: .normal)
    }

    @objc override func onBookPause() {
        guard let index = self.playlist.itemIndex(with: PlayerManager.shared.currentBook.fileURL),
            let bookCell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BookCellView else {
                return
        }

        bookCell.artworkButton.setImage(#imageLiteral(resourceName: "playerIconPause"), for: .normal)
    }
}

extension PlaylistViewController {
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        guard let bookCell = cell as? BookCellView,
            PlayerManager.shared.currentBook != nil,
            let index = self.playlist.itemIndex(with: PlayerManager.shared.currentBook.fileURL),
            index == indexPath.row else {
                return cell
        }

        bookCell.titleColor = UIColor(red: 0.37, green: 0.64, blue: 0.85, alpha: 1.0)
        bookCell.artworkButton.setImage(#imageLiteral(resourceName: "playerIconPlay"), for: .normal)

        return bookCell
    }
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

        guard let books = Array(self.items.suffix(from: indexPath.row)) as? [Book] else {
            return
        }

        self.setupPlayer(books: books)
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.section == 0, let book = self.items[indexPath.row] as? Book else {
            return nil
        }

        let deleteAction = UITableViewRowAction(style: .default, title: "Options") { (_, indexPath) in
            let sheet = UIAlertController(title: "\(book.title!)", message: nil, preferredStyle: .alert)

            sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

            sheet.addAction(UIAlertAction(title: "Remove from playlist", style: .default, handler: { _ in
                self.playlist.removeFromBooks(book)
                self.library.addToItems(book)

                DataManager.saveContext()

                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [indexPath], with: .none)
                self.tableView.endUpdates()

                NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.bookDeleted, object: nil)
            }))

            sheet.addAction(UIAlertAction(title: "Delete completely", style: .destructive, handler: { _ in
                do {
                    if book == PlayerManager.shared.currentBook {
                        PlayerManager.shared.stop()
                    }

                    self.playlist.removeFromBooks(book)

                    DataManager.saveContext()

                    try FileManager.default.removeItem(at: book.fileURL)

                    self.tableView.beginUpdates()
                    self.tableView.deleteRows(at: [indexPath], with: .none)
                    self.tableView.endUpdates()

                    NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.bookDeleted, object: nil)
                } catch {
                    self.showAlert("Error", message: "There was an error deleting the file, please try again.")
                }
            }))

            self.present(sheet, animated: true, completion: nil)
        }

        deleteAction.backgroundColor = UIColor.gray

        return [deleteAction]
    }
}
