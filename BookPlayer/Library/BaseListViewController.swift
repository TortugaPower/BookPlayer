//
//  BaseListViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import MediaPlayer
import MBProgressHUD
import SwiftReorder

class BaseListViewController: UIViewController {
    var library: Library!

    // TableView's datasource
    var items: [LibraryItem] {
        guard self.library != nil else {
            return []
        }

        return self.library.items?.array as? [LibraryItem] ?? []
    }

    @IBOutlet weak var tableView: UITableView!

    // keep in memory current Documents folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.register(UINib(nibName: "BookCellView", bundle: nil), forCellReuseIdentifier: "BookCellView")
        self.tableView.register(UINib(nibName: "AddCellView", bundle: nil), forCellReuseIdentifier: "AddCellView")

        self.tableView.reorder.delegate = self
        self.tableView.reorder.cellScale = 1.07

        self.tableView.reorder.shadowColor = UIColor.black
        self.tableView.reorder.shadowOffset = CGSize(width: 0.0, height: 3.0)
        self.tableView.reorder.shadowOpacity = 0.25
        self.tableView.reorder.shadowRadius = 8.0
        self.tableView.reorder.animationDuration = 0.15

        // Remove the line after the last cell
        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: tableView.frame.size.width, height: 1))

        // fixed tableview having strange offset
        self.edgesForExtendedLayout = UIRectEdge()

        // register notifications when the book is ready
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookReady), name: Notification.Name.AudiobookPlayer.bookReady, object: nil)

        // register for percentage change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.updatePercentage(_:)), name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil)
    }

    func presentImportFilesAlert() {
        let providerList = UIDocumentPickerViewController(documentTypes: ["public.audio"], in: .import)

        providerList.delegate = self

        self.present(providerList, animated: true, completion: nil)
    }

    func showPlayerView(book: Book) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.currentBook = book

            self.present(playerVC, animated: true)
        }
    }

    func setupPlayer(books: [Book]) {
        // Make sure player is for a different book
        let book = books.first!

        guard PlayerManager.shared.fileURL != book.fileURL else {
            showPlayerView(book: book)

            return
        }

        guard DataManager.exists(book) else {
            self.showAlert("File missing!", message: "This book’s file was removed from your device. Import the file again to play the book")
            return
        }

        MBProgressHUD.showAdded(to: self.view, animated: true)

        // Replace player with new one
        PlayerManager.shared.load(books) { (_) in
            self.showPlayerView(book: book)
            PlayerManager.shared.playPause()
        }
    }

    @objc func bookReady() {
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
    }

    @objc func loadFile(urls: [URL]) {
        fatalError("loadFiles must be overriden")
    }

    @objc func updatePercentage(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            let percentCompletedString = userInfo["percentCompletedString"] as? String else {
                return
        }

        guard let index = (self.items.index { (item) -> Bool in
            if let book = item as? Book {
                return book.fileURL == fileURL
            }
            return false
        }), let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BookCellView else {
            return
        }

        cell.completionLabel.text = percentCompletedString
    }
}

extension BaseListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == 0 else {
            return 1
        }

        return self.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let spacer = tableView.reorder.spacerCell(for: indexPath) {
            return spacer
        }

        guard indexPath.section == 0,
            let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as? BookCellView else {
                // Load add cell
                return tableView.dequeueReusableCell(withIdentifier: "AddCellView", for: indexPath)
        }

        let item = self.items[indexPath.row]

        cell.titleLabel.text = item.title

        if let book = item as? Book {
            cell.authorLabel.text = book.author

            cell.completionLabel.isHidden = false
            cell.completionLabel.text = item.percentCompletedRoundedString
            cell.completionLabel.textColor = UIColor.lightGray
        } else if let playlist = item as? Playlist {
            cell.authorLabel.text = playlist.info()
            cell.completionLabel.isHidden = true
        }

        cell.selectionStyle = .none

        // NOTE: We should have a default image for artwork
        cell.artworkImageView.image = item.artwork
        cell.artworkImageView.layer.cornerRadius = 4.0
        cell.artworkImageView.layer.masksToBounds = true

        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
}

extension BaseListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCellEditingStyle {
        guard indexPath.section == 0 else {
            return .insert
        }
        return .delete
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        guard let index = tableView.indexPathForSelectedRow else {
            return indexPath
        }

        tableView.deselectRow(at: index, animated: true)

        return indexPath
    }
}

extension BaseListViewController: TableViewReorderDelegate {
    @objc func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {}

    func tableView(_ tableView: UITableView, canReorderRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 0
    }

    func tableView(_ tableView: UITableView, targetIndexPathForReorderFromRowAt sourceIndexPath: IndexPath, to proposedDestinationIndexPath: IndexPath, snapshot: UIView?) -> IndexPath {
        guard proposedDestinationIndexPath.section == 0 else {
            return sourceIndexPath
        }

        if let snapshot = snapshot {
            UIView.animate(withDuration: 0.2) {
                snapshot.transform = CGAffineTransform.identity
            }
        }

        return proposedDestinationIndexPath
    }

    func tableView(_ tableView: UITableView, sourceIndexPath: IndexPath, overIndexPath: IndexPath, snapshot: UIView) {
        guard overIndexPath.section == 0 else {
            return
        }

        let scale: CGFloat = 0.90

        UIView.animate(withDuration: 0.2, delay: 0.0, options: .curveEaseOut, animations: {
            snapshot.transform = CGAffineTransform(scaleX: scale, y: scale)
        })
    }

    @objc func tableViewDidFinishReordering(_ tableView: UITableView, from initialSourceIndexPath: IndexPath, to finalDestinationIndexPath: IndexPath, dropped overIndexPath: IndexPath?) {}
}

extension BaseListViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else {
            return
        }

        // @TODO: Consider importing multiple files at once

        self.addFileFromUrl(url)
    }

    func addFileFromUrl(_ url: URL) {
        // Documentation states that the file might not be imported due to being accessed from somewhere else

        do {
            try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            self.showAlert("Error", message: "There was an error reading the file, please try again.")

            return
        }

        let trueName = url.lastPathComponent
        var finalPath = self.documentsPath + "/" + (trueName)

        if trueName.contains(" ") {
            finalPath = finalPath.replacingOccurrences(of: " ", with: "_")
        }

        let fileURL = URL(fileURLWithPath: finalPath.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)

        do {
            try FileManager.default.moveItem(at: url, to: fileURL)
        } catch {
            self.showAlert("Error", message: "There was an error importing the file, please try again.")

            return
        }

        MBProgressHUD.showAdded(to: self.view, animated: true)

        DataManager.processPendingFiles { (urls) in
            self.loadFile(urls: urls)
        }
    }
}
