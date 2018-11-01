//
//  RootViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/12/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class RootViewController: UIViewController, UIGestureRecognizerDelegate {
    @IBOutlet private var miniPlayerContainer: UIView!

    private weak var miniPlayerViewController: MiniPlayerViewController?
    private weak var libraryViewController: LibraryViewController!

    private var pan: UIPanGestureRecognizer!

    var miniPlayerIsHidden: Bool {
        return self.miniPlayerContainer.isHidden
    }

    // MARK: - Lifecycle

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
        if let viewController = segue.destination as? MiniPlayerViewController {
            miniPlayerViewController = viewController
            miniPlayerViewController!.showPlayer = {
                guard let currentBook = PlayerManager.shared.currentBook else {
                    return
                }

                self.libraryViewController.setupPlayer(book: currentBook)
            }
        } else if
            let navigationVC = segue.destination as? UINavigationController,
            let libraryVC = navigationVC.childViewControllers.first as? LibraryViewController {
            libraryViewController = libraryVC
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        miniPlayerContainer.isHidden = true
        miniPlayerContainer.layer.shadowColor = UIColor.black.cgColor
        miniPlayerContainer.layer.shadowOffset = CGSize(width: 0.0, height: 4.0)
        miniPlayerContainer.layer.shadowOpacity = 0.2
        miniPlayerContainer.layer.shadowRadius = 12.0
        miniPlayerContainer.clipsToBounds = false

        NotificationCenter.default.addObserver(self, selector: #selector(bookChange(_:)), name: .bookChange, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(bookReady(_:)), name: .bookReady, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dismissMiniPlayer), name: .playerPresented, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(presentMiniPlayer), name: .playerDismissed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBookPlay), name: .bookPlayed, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBookPause), name: .bookPaused, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onBookPause), name: .bookEnd, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dismissMiniPlayer), name: .bookStopped, object: nil)

        // Gestures
        pan = UIPanGestureRecognizer(target: self, action: #selector(panAction))
        pan.delegate = self
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true

        view.addGestureRecognizer(pan)
    }

    // MARK: -

    @objc private func presentMiniPlayer() {
        miniPlayerContainer.transform = CGAffineTransform(translationX: 0, y: miniPlayerContainer.bounds.height)
        miniPlayerContainer.alpha = 0.0
        miniPlayerContainer.isHidden = false

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

        UIView.animate(
            withDuration: 0.3, delay: 0.0, options: .preferredFramesPerSecond60, animations: {
                self.miniPlayerContainer.alpha = 1.0
            }
        )
    }

    @objc private func dismissMiniPlayer() {
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

        UIView.animate(
            withDuration: 0.15, delay: 0.0, options: [.preferredFramesPerSecond60, .curveEaseIn], animations: {
                self.miniPlayerContainer.alpha = 0.0
            }
        )
    }

    @objc private func bookChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book
        else {
            return
        }

        setupMiniPlayer(book: book)

        PlayerManager.shared.play()
    }

    @objc private func bookReady(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
            let book = userInfo["book"] as? Book
        else {
            return
        }

        setupMiniPlayer(book: book)
    }

    @objc private func onBookPlay() {
        pan.isEnabled = false
    }

    @objc private func onBookPause() {
        // Only enable the gesture to dismiss the Mini Player when the book is paused
        pan.isEnabled = true
    }

    // MARK: - Helpers

    private func setupMiniPlayer(book: Book) {
        miniPlayerViewController?.book = book
    }

    // MARK: - Gesture recognizers

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == pan {
            return limitPanAngle(pan, degreesOfFreedom: 45.0, comparator: .greaterThan)
        }

        return true
    }

    private func updatePresentedViewForTranslation(_ yTranslation: CGFloat) {
        let translation: CGFloat = rubberBandDistance(yTranslation, dimension: view.frame.height, constant: 0.55)

        miniPlayerContainer?.transform = CGAffineTransform(translationX: 0, y: max(translation, 0.0))
    }

    @objc private func panAction(gestureRecognizer: UIPanGestureRecognizer) {
        guard gestureRecognizer.isEqual(pan) else {
            return
        }

        switch gestureRecognizer.state {
        case .began:
            gestureRecognizer.setTranslation(CGPoint(x: 0, y: 0), in: view.superview)

        case .changed:
            let translation = gestureRecognizer.translation(in: view)

            updatePresentedViewForTranslation(translation.y)

        case .ended, .cancelled, .failed:
            let dismissThreshold: CGFloat = miniPlayerContainer.bounds.height / 2
            let translation = gestureRecognizer.translation(in: view)

            if translation.y > dismissThreshold {
                PlayerManager.shared.stop()

                return
            }

            UIView.animate(
                withDuration: 0.3,
                delay: 0.0,
                usingSpringWithDamping: 0.75,
                initialSpringVelocity: 1.5,
                options: .preferredFramesPerSecond60,
                animations: {
                    self.miniPlayerContainer?.transform = .identity
                }
            )

        default: break
        }
    }
}
