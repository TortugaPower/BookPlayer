//
//  RootViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {
    @IBOutlet private weak var nowPlayingBar: UIView!

    private weak var nowPlayingViewController: NowPlayingViewController?
    private weak var libraryViewController: LibraryViewController!

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? NowPlayingViewController {
            self.nowPlayingViewController = viewController

            self.nowPlayingViewController!.showPlayer = {

                guard PlayerManager.shared.currentBook != nil else {
                    return
                }

                self.libraryViewController.setupPlayer(books: PlayerManager.shared.currentBooks)
            }
        } else if let navigationVC = segue.destination as? UINavigationController,
            let libraryVC = navigationVC.childViewControllers.first as? LibraryViewController {
            self.libraryViewController = libraryVC
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.nowPlayingBar.isHidden = true

        // register for book change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookChange(_:)), name: Notification.Name.AudiobookPlayer.bookChange, object: nil)

        // register for book loading notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookLoading(_:)), name: Notification.Name.AudiobookPlayer.loadingBook, object: nil)
    }

    @objc func bookChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let books = userInfo["books"] as? [Book],
            let currentBook = books.first else {
                return
        }

        setupFooter(book: currentBook)
        PlayerManager.shared.play()
    }

    @objc func bookLoading(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book else {
                return
        }

        setupFooter(book: book)
    }

    func setupFooter(book: Book) {
        self.nowPlayingBar.isHidden = false
        self.nowPlayingViewController?.book = book
    }
}
