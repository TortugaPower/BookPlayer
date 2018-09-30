//
//  RootViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit

class RootViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet private weak var miniPlayerContainer: UIView!

    private weak var miniPlayerViewController: MiniPlayerViewController?
    private weak var libraryViewController: LibraryViewController!

    private var pan: UIPanGestureRecognizer!

    var miniPlayerIsHidden: Bool {
        return self.miniPlayerContainer.isHidden
    }

    // MARK: - Lifecycle

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let viewController = segue.destination as? MiniPlayerViewController {
            self.miniPlayerViewController = viewController
            self.miniPlayerViewController!.showPlayer = {
                guard let currentBook = PlayerManager.shared.currentBook else {
                    return
                }

                self.libraryViewController.setupPlayer(book: currentBook)
            }
        } else if
            let navigationVC = segue.destination as? UINavigationController,
            let libraryVC = navigationVC.childViewControllers.first as? LibraryViewController {
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

        NotificationCenter.default.addObserver(self, selector: #selector(self.bookChange(_:)), name: .bookChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookReady(_:)), name: .bookReady, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissMiniPlayer), name: .playerPresented, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.presentMiniPlayer), name: .playerDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPlay), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: .bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.onBookPause), name: .bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.dismissMiniPlayer), name: .bookStopped, object: nil)

        // Gestures
        self.pan = UIPanGestureRecognizer(target: self, action: #selector(self.panAction))
        self.pan.delegate = self
        self.pan.maximumNumberOfTouches = 1
        self.pan.cancelsTouchesInView = true

        view.addGestureRecognizer(self.pan)
    }

    // MARK: -

    @objc private func presentMiniPlayer() {
        self.miniPlayerContainer.transform = CGAffineTransform(translationX: 0, y: self.miniPlayerContainer.bounds.height)
        self.miniPlayerContainer.alpha = 0.0
        self.miniPlayerContainer.isHidden = false

        UIView.animate(withDuration: 0.5,
                       delay: 0.0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 1.5,
                       options: .preferredFramesPerSecond60,
                       animations: {
                           self.miniPlayerContainer.transform = .identity
        })

        UIView.animate(withDuration: 0.3, delay: 0.0, options: .preferredFramesPerSecond60, animations: {
            self.miniPlayerContainer.alpha = 1.0
        })
    }

    @objc private func dismissMiniPlayer() {
        UIView.animate(withDuration: 0.25,
                       delay: 0.0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 1.5,
                       options: .preferredFramesPerSecond60,
                       animations: {
                           self.miniPlayerContainer.transform = CGAffineTransform(translationX: 0, y: self.miniPlayerContainer.bounds.height)
                       },
                       completion: { _ in
                           self.miniPlayerContainer.isHidden = true
        })

        UIView.animate(withDuration: 0.15, delay: 0.0, options: [.preferredFramesPerSecond60, .curveEaseIn], animations: {
            self.miniPlayerContainer.alpha = 0.0
        })
    }

    @objc private func bookChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book
        else {
            return
        }

        self.setupMiniPlayer(book: book)

        PlayerManager.shared.play()
    }

    @objc private func bookReady(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book
        else {
            return
        }

        self.setupMiniPlayer(book: book)
    }

    @objc private func onBookPlay() {
        self.pan.isEnabled = false
    }

    @objc private func onBookPause() {
        // Only enable the gesture to dismiss the Mini Player when the book is paused
        self.pan.isEnabled = true
    }

    // MARK: - Helpers

    private func setupMiniPlayer(book: Book) {
        self.miniPlayerViewController?.book = book
    }

    // MARK: - Gesture recognizers

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == self.pan {
            return limitPanAngle(self.pan, degreesOfFreedom: 45.0, comparator: .greaterThan)
        }

        return true
    }

    private func updatePresentedViewForTranslation(_ yTranslation: CGFloat) {
        let translation: CGFloat = rubberBandDistance(yTranslation, dimension: self.view.frame.height, constant: 0.55)

        self.miniPlayerContainer?.transform = CGAffineTransform(translationX: 0, y: max(translation, 0.0))
    }

    @objc private func panAction(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(self.pan) else {
            return
        }

        switch gestureRecognizer.state {
        case .began:
            gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: self.view.superview)

        case .changed:
            let translation = gestureRecognizer.translation(in: self.view)

            self.updatePresentedViewForTranslation(translation.y)

        case .ended, .cancelled, .failed:
            let dismissThreshold: CGFloat = self.miniPlayerContainer.bounds.height / 2
            let translation = gestureRecognizer.translation(in: self.view)

            if translation.y > dismissThreshold {
                PlayerManager.shared.stop()

                return
            }

            UIView.animate(withDuration: 0.3,
                           delay: 0.0,
                           usingSpringWithDamping: 0.75,
                           initialSpringVelocity: 1.5,
                           options: .preferredFramesPerSecond60,
                           animations: {
                               self.miniPlayerContainer?.transform = .identity
            })

        default: break
        }
    }
}
