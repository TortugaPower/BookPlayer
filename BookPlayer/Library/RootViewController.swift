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

    var playerVisible: Bool = false

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? NowPlayingViewController {
            self.nowPlayingViewController = viewController
            self.nowPlayingViewController!.showPlayer = {
                guard PlayerManager.shared.currentBook != nil else {
                    return
                }

                self.libraryViewController.setupPlayer(books: PlayerManager.shared.currentBooks)
            }
        } else if let navigationVC = segue.destination as? UINavigationController, let libraryVC = navigationVC.childViewControllers.first as? LibraryViewController {
            self.libraryViewController = libraryVC
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.nowPlayingBar.isHidden = true
        self.nowPlayingBar.layer.shadowColor = UIColor.black.cgColor
        self.nowPlayingBar.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        self.nowPlayingBar.layer.shadowOpacity = 0.2
        self.nowPlayingBar.layer.shadowRadius = 12.0
        self.nowPlayingBar.clipsToBounds = false

        // Register for book change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookChange(_:)), name: Notification.Name.AudiobookPlayer.bookChange, object: nil)

        // Register for book loading notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookLoading(_:)), name: Notification.Name.AudiobookPlayer.loadingBook, object: nil)

        //
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissMiniPlayer), name: Notification.Name.AudiobookPlayer.playerPresented, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.presentMiniPlayer), name: Notification.Name.AudiobookPlayer.playerDismissed, object: nil)
    }

    @objc func presentMiniPlayer() {
        self.playerVisible = false

        self.nowPlayingBar.transform = CGAffineTransform(translationX: 0, y: self.nowPlayingBar.bounds.height)
        self.nowPlayingBar.alpha = 0.0
        self.nowPlayingBar.isHidden = false

        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 1.5,
            options: .preferredFramesPerSecond60,
            animations: {
                self.nowPlayingBar.transform = .identity
            }
        )

        UIView.animate(withDuration: 0.3, delay: 0.0, options: .preferredFramesPerSecond60, animations: {
            self.nowPlayingBar.alpha = 1.0
        })
    }

    @objc func dismissMiniPlayer() {
        self.playerVisible = true

        UIView.animate(
            withDuration: 0.25,
            delay: 0.0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 1.5,
            options: .preferredFramesPerSecond60,
            animations: {
                self.nowPlayingBar.transform = CGAffineTransform(translationX: 0, y: self.nowPlayingBar.bounds.height)
            },
            completion: { _ in
                self.nowPlayingBar.isHidden = true
            }
        )

        UIView.animate(withDuration: 0.15, delay: 0.0, options: [.preferredFramesPerSecond60, .curveEaseIn], animations: {
            self.nowPlayingBar.alpha = 0.0
        })
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
        self.nowPlayingViewController?.book = book
    }
}
