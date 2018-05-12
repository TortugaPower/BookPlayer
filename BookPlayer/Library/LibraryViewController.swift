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

class LibraryViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet weak var emptyListContainerView: UIView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet private weak var nowPlayingBar: UIView!

    private weak var nowPlayingViewController: NowPlayingViewController?

    var currentBooks: [Book] = []
    // TableView's datasource
    var bookArray = [Book]()

    var library: Library!

    // keep in memory current Documents folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? NowPlayingViewController {
            self.nowPlayingViewController = viewController

            self.nowPlayingViewController!.showPlayer = {
                guard !self.currentBooks.isEmpty else {
                    return
                }

                self.play(books: self.currentBooks)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // enables pop gesture on pushed controller
        self.navigationController!.interactivePopGestureRecognizer!.delegate = self

        self.tableView.register(UINib(nibName: "BookCellView", bundle: nil), forCellReuseIdentifier: "BookCellView")
        self.tableView.register(UINib(nibName: "AddCellView", bundle: nil), forCellReuseIdentifier: "AddCellView")
        self.tableView.reorder.delegate = self
        self.tableView.reorder.cellScale = 1.05
        self.tableView.tableFooterView = UIView()
        // fixed tableview having strange offset
        self.edgesForExtendedLayout = UIRectEdge()

        self.nowPlayingBar.isHidden = true

        // register for appDelegate openUrl notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.loadFiles), name: Notification.Name.AudiobookPlayer.openURL, object: nil)

        // register for percentage change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.updatePercentage(_:)), name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil)

        // register notifications when the book is ready
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookReady), name: Notification.Name.AudiobookPlayer.bookReady, object: nil)

        // register for book change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookChange(_:)), name: Notification.Name.AudiobookPlayer.bookChange, object: nil)

        self.loadFiles()
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
    @objc func loadFiles() {
        //load local files
        let loadingWheel = MBProgressHUD.showAdded(to: self.view, animated: true)
        loadingWheel?.labelText = "Loading Books"

        DataManager.loadLibrary { (library) in
            // swiftlint:disable force_cast
            self.library = library
            self.bookArray = library.items?.array as! [Book]
            MBProgressHUD.hideAllHUDs(for: self.view, animated: true)

            //show/hide instructions view
            self.emptyListContainerView.isHidden = !self.bookArray.isEmpty
            self.tableView.reloadData()
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return navigationController!.viewControllers.count > 1
    }

    @IBAction func didPressReload(_ sender: UIBarButtonItem) {
        self.loadFiles()
    }

    @IBAction func didPressPlay(_ sender: UIButton) {
        PlayerManager.shared.play()
    }

    @objc func forwardPressed(_ sender: UIButton) {
        PlayerManager.shared.forward()
    }

    @objc func rewindPressed(_ sender: UIButton) {
        PlayerManager.shared.rewind()
    }

    // Percentage callback
    @objc func updatePercentage(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            let percentCompletedString = userInfo["percentCompletedString"] as? String else {
                return
        }

        guard let index = (self.bookArray.index { (book) -> Bool in
            return book.fileURL == fileURL
        }), let cell = self.tableView.cellForRow(at: IndexPath(row: index, section: 0)) as? BookCellView else {
            return
        }

        cell.completionLabel.text = percentCompletedString
    }

    @objc func bookReady() {
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
        PlayerManager.shared.playPause(autoplayed: true)
    }

    @objc func bookChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let books = userInfo["books"] as? [Book],
            let currentBook = books.first else {
                return
        }

        setupFooter(book: currentBook)
    }

}

extension LibraryViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == 0 else {
            return 1
        }

        return self.bookArray.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let spacer = tableView.reorder.spacerCell(for: indexPath) {
            return spacer
        }

        guard indexPath.section == 0,
            let cell = tableView.dequeueReusableCell(withIdentifier: "BookCellView", for: indexPath) as? BookCellView else {
                //load add cell
                return tableView.dequeueReusableCell(withIdentifier: "AddCellView", for: indexPath)
        }

        let book = self.bookArray[indexPath.row]

        cell.titleLabel.text = book.title
        cell.authorLabel.text = book.author

        cell.selectionStyle = .none

        // NOTE: we should have a default image for artwork
        cell.artworkImageView.image = book.artworkImage

        // Load stored percentage value
        cell.completionLabel.text = book.percentCompletedRoundedString
        cell.completionLabel.textColor = UIColor.lightGray

        return cell
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
}

extension LibraryViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, canFocusRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        guard indexPath.section == 0 else {
            return nil
        }

        let deleteAction = UITableViewRowAction(style: .default, title: "Delete") { (_, indexPath) in
            let alert = UIAlertController(title: "Confirmation", message: "Are you sure you would like to remove this audiobook?", preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "No", style: .cancel, handler: { _ in
                tableView.setEditing(false, animated: true)
            }))

            alert.addAction(UIAlertAction(title: "Yes", style: .destructive, handler: { _ in
                let book = self.bookArray[indexPath.row]

                do {
                    self.library.removeFromItems(book)
                    DataManager.saveContext()

                    try FileManager.default.removeItem(at: book.fileURL)

                    self.bookArray.remove(at: indexPath.row)
                    tableView.beginUpdates()
                    tableView.deleteRows(at: [indexPath], with: .none)
                    tableView.endUpdates()
                    self.emptyListContainerView.isHidden = !self.bookArray.isEmpty
                } catch {
                    self.showAlert("Error", message: "There was an error deleting the book, please try again.")
                }
            }))

            alert.popoverPresentationController?.sourceView = self.view
            alert.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)

            self.present(alert, animated: true, completion: nil)
        }

        deleteAction.backgroundColor = UIColor.red

        return [deleteAction]
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
                }))

                self.present(playlistAlert, animated: true, completion: nil)
            })

            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

            self.present(alertController, animated: true, completion: nil)

            return
        }

        let books = Array(self.bookArray.suffix(from: indexPath.row))

        play(books: books)
    }

    func play(books: [Book]) {
        guard !books.isEmpty else {
            return
        }

        self.currentBooks = books

        let book = currentBooks.first!

        setupPlayer(book: book)
        setupFooter(book: book)
    }

    func setupPlayer(book: Book) {
        // Make sure player is for a different book
        guard PlayerManager.shared.fileURL != book.fileURL else {
            showPlayerView(book: book)

            return
        }

        MBProgressHUD.showAdded(to: self.view, animated: true)

        // Replace player with new one
        PlayerManager.shared.load(self.currentBooks) { (_) in
            self.showPlayerView(book: book)
        }
    }

    func setupFooter(book: Book) {
        self.nowPlayingBar.isHidden = false
        self.nowPlayingViewController?.book = book
    }

    func showPlayerView(book: Book) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        if let playerVC = storyboard.instantiateViewController(withIdentifier: "PlayerViewController") as? PlayerViewController {
            playerVC.currentBook = book

            self.present(playerVC, animated: true)
        }
    }
}

extension LibraryViewController: UIDocumentMenuDelegate {
    @IBAction func didPressImportOptions(_ sender: UIBarButtonItem) {
        let sheet = UIAlertController(title: "Import Books", message: nil, preferredStyle: .actionSheet)
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)

        let localButton = UIAlertAction(title: "From Local Apps", style: .default) { (_) in
            let providerList = UIDocumentMenuViewController(documentTypes: ["public.audio"], in: .import)
            providerList.delegate = self

            providerList.popoverPresentationController?.sourceView = self.view
            providerList.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)
            self.present(providerList, animated: true, completion: nil)
        }

        let airdropButton = UIAlertAction(title: "AirDrop", style: .default) { (_) in
            self.showAlert("AirDrop", message: "Make sure AirDrop is enabled.\n\nOnce you transfer the file to your device via AirDrop, choose 'BookPlayer' from the app list that will appear")
        }

        sheet.addAction(localButton)
        sheet.addAction(airdropButton)
        sheet.addAction(cancelButton)

        sheet.popoverPresentationController?.sourceView = self.view
        sheet.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)

        self.present(sheet, animated: true, completion: nil)
    }

    func documentMenu(_ documentMenu: UIDocumentMenuViewController, didPickDocumentPicker documentPicker: UIDocumentPickerViewController) {
        //show document picker
        documentPicker.delegate = self

        documentPicker.popoverPresentationController?.sourceView = self.view
        documentPicker.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)

        self.present(documentPicker, animated: true, completion: nil)
    }
}

extension LibraryViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        //Documentation states that the file might not be imported due to being accessed from somewhere else
        do {
            try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            self.showAlert("Error", message: "File import fail, try again later")

            return
        }

        let trueName = url.lastPathComponent
        var finalPath = self.documentsPath+"/"+(trueName)

        if trueName.contains(" ") {
            finalPath = finalPath.replacingOccurrences(of: " ", with: "_")
        }

        let fileURL = URL(fileURLWithPath: finalPath.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!)

        do {
            try FileManager.default.moveItem(at: url, to: fileURL)
        } catch {
            self.showAlert("Error", message: "File import fail, try again later")

            return
        }

        self.loadFiles()
    }
}

extension LibraryViewController: TableViewReorderDelegate {
    func tableView(_ tableView: UITableView, reorderRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard destinationIndexPath.section == 0 else {
            return
        }

        let book = self.bookArray[sourceIndexPath.row]
        self.library.removeFromItems(at: sourceIndexPath.row)
        self.library.insertIntoItems(book, at: destinationIndexPath.row)
        DataManager.saveContext()
        self.bookArray.remove(at: sourceIndexPath.row)
        self.bookArray.insert(book, at: destinationIndexPath.row)
    }

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

        UIView.animate(withDuration: 0.2) {
            snapshot.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }
    }

    func tableViewDidFinishReordering(_ tableView: UITableView, from initialSourceIndexPath: IndexPath, to finalDestinationIndexPath: IndexPath, dropped overIndexPath: IndexPath?) {
    }
}
