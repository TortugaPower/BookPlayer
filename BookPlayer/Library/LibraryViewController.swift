//
//  LibraryViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 7/7/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import MediaPlayer
import MBProgressHUD
import SwiftReorder

class LibraryViewController: BaseListViewController, UIGestureRecognizerDelegate {

    @IBOutlet weak var emptyListContainerView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // enables pop gesture on pushed controller
        self.navigationController!.interactivePopGestureRecognizer!.delegate = self

        // register for appDelegate openUrl notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.openURL(_:)), name: Notification.Name.AudiobookPlayer.openURL, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(self.reloadData), name: Notification.Name.AudiobookPlayer.bookDeleted, object: nil)

        self.loadLibrary()
    }

    // No longer need to deregister observers for iOS 9+!
    // https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11NotificationCenter
    deinit {
        //for iOS 8
        NotificationCenter.default.removeObserver(self)
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    /**
     *  Load local files and process them (rename them if necessary)
     *  Spaces in file names can cause side effects when trying to load the data
     */
    func loadLibrary() {
        //load local files
        let loadingWheel = MBProgressHUD.showAdded(to: self.view, animated: true)
        loadingWheel?.labelText = "Loading Books"

        self.library = DataManager.getLibrary()

        //show/hide instructions view
        self.emptyListContainerView.isHidden = !self.items.isEmpty
        self.tableView.reloadData()

        DataManager.processPendingFiles { (urls) in
            guard !urls.isEmpty else {
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
                return
            }

            DataManager.insertBooks(from: urls, into: self.library) {
                MBProgressHUD.hideAllHUDs(for: self.view, animated: true)

                //show/hide instructions view
                self.emptyListContainerView.isHidden = !self.items.isEmpty
                self.tableView.reloadData()
            }
        }
    }

    override func loadFile(urls: [URL]) {
        DataManager.insertBooks(from: urls, into: self.library) {
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
            self.emptyListContainerView.isHidden = !self.items.isEmpty
            self.tableView.reloadData()
        }
    }

    @objc func openURL(_ notification: Notification) {
        MBProgressHUD.showAdded(to: self.view, animated: true)

        DataManager.processPendingFiles { (urls) in
            self.loadFile(urls: urls)
        }
    }

    @objc func reloadData() {
        self.tableView.reloadData()
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return navigationController!.viewControllers.count > 1
    }

    func handleDelete(book: Book, indexPath: IndexPath) {
        let alert = UIAlertController(title: "Confirmation", message: "Are you sure you would like to remove this audiobook?", preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { _ in
            self.tableView.setEditing(false, animated: true)
        }))

        alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
            do {
                self.library.removeFromItems(book)
                DataManager.saveContext()

                try FileManager.default.removeItem(at: book.fileURL)

                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [indexPath], with: .none)
                self.tableView.endUpdates()
                self.emptyListContainerView.isHidden = !self.items.isEmpty
            } catch {
                self.showAlert("Error", message: "There was an error deleting the book, please try again.")
            }
        }))

        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)

        self.present(alert, animated: true, completion: nil)
    }

    func handleDelete(playlist: Playlist, indexPath: IndexPath) {
        let sheet = UIAlertController(title: "Delete Playlist", message: nil, preferredStyle: .actionSheet)

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        sheet.addAction(UIAlertAction(title: "Preserve books", style: .default, handler: { _ in
            if let orderedSet = playlist.books {
                self.library.addToItems(orderedSet)
            }
            self.library.removeFromItems(playlist)
            DataManager.saveContext()

            self.tableView.beginUpdates()
            self.tableView.reloadSections(IndexSet(integer: 0), with: .fade)
            self.tableView.endUpdates()
            self.emptyListContainerView.isHidden = !self.items.isEmpty
        }))

        sheet.addAction(UIAlertAction(title: "Delete books too", style: .destructive, handler: { _ in
            do {

                self.library.removeFromItems(playlist)
                DataManager.saveContext()

                // swiftlint:disable force_cast
                for book in playlist.books?.array as! [Book] {
                    try FileManager.default.removeItem(at: book.fileURL)
                }

                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [indexPath], with: .none)
                self.tableView.endUpdates()
                self.emptyListContainerView.isHidden = !self.items.isEmpty
            } catch {
                self.showAlert("Error", message: "There was an error deleting the book, please try again.")
            }
        }))

        self.present(sheet, animated: true, completion: nil)
    }
}

extension LibraryViewController {

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.section == 0 else {
            return nil
        }

        let item = self.items[indexPath.row]

        let isPlaylist = item is Playlist

        let title = isPlaylist ? "Options" : "Delete"
        let color = isPlaylist ? UIColor.gray : UIColor.red

        let deleteAction = UITableViewRowAction(style: .default, title: title) { (_, indexPath) in

            guard let book = item as? Book else {
                // swiftlint:disable force_cast
                self.handleDelete(playlist: item as! Playlist, indexPath: indexPath)
                return
            }

            self.handleDelete(book: book, indexPath: indexPath)
        }

        deleteAction.backgroundColor = color

        return [deleteAction]
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard indexPath.section == 0 else {
            let alertController = UIAlertController(title: nil, message: "You can also add files via AirDrop. Select BookPlayer from the list that appears when you send a file to your device", preferredStyle: .actionSheet)
            alertController.addAction(UIAlertAction(title: "Import Files", style: .default) { (_) in
                let providerList = UIDocumentMenuViewController(documentTypes: ["public.audio"], in: .import)
                providerList.delegate = self

                providerList.popoverPresentationController?.sourceView = self.view
                providerList.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)
                self.present(providerList, animated: true, completion: nil)
            })

            alertController.addAction(UIAlertAction(title: "Create Playlist", style: .default) { (_) in

                let playlistAlert = UIAlertController(title: "Create a New Playlist", message: "Files in playlists are automatically played one after the other", preferredStyle: .alert)
                playlistAlert.addTextField(configurationHandler: { (textfield) in
                    textfield.placeholder = "Name"
                })
                playlistAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
                playlistAlert.addAction(UIAlertAction(title: "Create", style: .default, handler: { (_) in
                    let title = playlistAlert.textFields!.first!.text!

                    let playlist = DataManager.createPlaylist(title: title, books: [])
                    self.library.addToItems(playlist)
                    DataManager.saveContext()

                    self.tableView.reloadData()
                }))

                self.present(playlistAlert, animated: true, completion: nil)
            })

            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            self.present(alertController, animated: true, completion: nil)

            return
        }

        let item = self.items[indexPath.row]

        guard let book = item as? Book else {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)

            if let playlist = item as? Playlist,
                let playlistVC = storyboard.instantiateViewController(withIdentifier: "PlaylistViewController") as? PlaylistViewController {
                playlistVC.library = self.library
                playlistVC.playlist = playlist
                self.navigationController?.pushViewController(playlistVC, animated: true)
            }
            return
        }

        self.setupPlayer(books: [book])
    }
}

extension LibraryViewController {
    override func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard destinationIndexPath.section == 0 else {
            return
        }

        let item = self.items[sourceIndexPath.row]
        self.library.removeFromItems(at: sourceIndexPath.row)
        self.library.insertIntoItems(item, at: destinationIndexPath.row)
        DataManager.saveContext()
    }

    override func tableViewDidFinishReordering(_ tableView: UITableView, from initialSourceIndexPath: IndexPath, to finalDestinationIndexPath: IndexPath, dropped overIndexPath: IndexPath?) {
        guard let overIndexPath = overIndexPath,
            overIndexPath.section == 0,
            let book = self.items[finalDestinationIndexPath.row] as? Book else {
                return
        }

        let item = self.items[overIndexPath.row]
        let isPlaylist = item is Playlist
        let title = isPlaylist
            ? "Playlist"
            : "Create a New Playlist"
        let message = isPlaylist
            ? "Add the book to \(item.title!)"
            : "Files in playlists are automatically played one after the other"

        let hoverAlert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        hoverAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        if isPlaylist {
            hoverAlert.addAction(UIAlertAction(title: "Add", style: .default, handler: { (_) in

                if let playlist = item as? Playlist {
                    playlist.addToBooks(book)
                }
                self.library.removeFromItems(at: finalDestinationIndexPath.row)
                DataManager.saveContext()
                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [finalDestinationIndexPath], with: .fade)
                self.tableView.reloadRows(at: [overIndexPath], with: .fade)
                self.tableView.endUpdates()
            }))
        } else {
            hoverAlert.addTextField(configurationHandler: { (textfield) in
                textfield.placeholder = "Name"
            })

            hoverAlert.addAction(UIAlertAction(title: "Create", style: .default, handler: { (_) in
                let title = hoverAlert.textFields!.first!.text!

                let minIndex = min(finalDestinationIndexPath.row, overIndexPath.row)

                //removing based on minIndex works because the cells are always adjacent
                let book1 = self.items[minIndex]
                self.library.removeFromItems(book1)
                let book2 = self.items[minIndex]
                self.library.removeFromItems(book2)

                // swiftlint:disable force_cast
                let books = [book1 as! Book, book2 as! Book]
                let playlist = DataManager.createPlaylist(title: title, books: books)
                self.library.insertIntoItems(playlist, at: minIndex)
                DataManager.saveContext()

                self.tableView.beginUpdates()
                self.tableView.deleteRows(at: [IndexPath(row: minIndex, section: 0), IndexPath(row: minIndex + 1, section: 0)], with: .fade)
                self.tableView.insertRows(at: [IndexPath(row: minIndex, section: 0)], with: .fade)
                self.tableView.endUpdates()
            }))
        }

        self.present(hoverAlert, animated: true, completion: nil)
    }
}
