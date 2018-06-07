//
//  RootViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {
    @IBOutlet private weak var miniPlayerContainer: UIView!

    private weak var miniPlayerViewController: MiniPlayerViewController?
    private weak var libraryViewController: LibraryViewController!

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? MiniPlayerViewController {
            self.miniPlayerViewController = viewController
            self.miniPlayerViewController!.showPlayer = {
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

        self.miniPlayerContainer.isHidden = true
        self.miniPlayerContainer.layer.shadowColor = UIColor.black.cgColor
        self.miniPlayerContainer.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        self.miniPlayerContainer.layer.shadowOpacity = 0.2
        self.miniPlayerContainer.layer.shadowRadius = 12.0
        self.miniPlayerContainer.clipsToBounds = false

        // Register for book change notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookChange(_:)), name: Notification.Name.AudiobookPlayer.bookChange, object: nil)

        // Register for book loading notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookReady(_:)), name: Notification.Name.AudiobookPlayer.bookReady, object: nil)

        //
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissMiniPlayer), name: Notification.Name.AudiobookPlayer.playerPresented, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.presentMiniPlayer), name: Notification.Name.AudiobookPlayer.playerDismissed, object: nil)
    }

    @objc func presentMiniPlayer() {
        self.miniPlayerContainer.transform = CGAffineTransform(translationX: 0, y: self.miniPlayerContainer.bounds.height)
        self.miniPlayerContainer.alpha = 0.0
        self.miniPlayerContainer.isHidden = false

        UIView.animate(
            withDuration: 0.5,
            delay: 0.0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 1.5,
            options: .preferredFramesPerSecond60,
            animations: {
                self.miniPlayerContainer.transform = .identity
            }
        )

        UIView.animate(withDuration: 0.3, delay: 0.0, options: .preferredFramesPerSecond60, animations: {
            self.miniPlayerContainer.alpha = 1.0
        })
    }

    @objc func dismissMiniPlayer() {
        UIView.animate(
            withDuration: 0.25,
            delay: 0.0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 1.5,
            options: .preferredFramesPerSecond60,
            animations: {
                self.miniPlayerContainer.transform = CGAffineTransform(translationX: 0, y: self.miniPlayerContainer.bounds.height)
            },
            completion: { _ in
                self.miniPlayerContainer.isHidden = true
            }
        )

        UIView.animate(withDuration: 0.15, delay: 0.0, options: [.preferredFramesPerSecond60, .curveEaseIn], animations: {
            self.miniPlayerContainer.alpha = 0.0
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

    @objc func bookReady(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book else {
                return
        }

        setupFooter(book: book)
    }

    func setupFooter(book: Book) {
        self.miniPlayerViewController?.book = book
    }
}
