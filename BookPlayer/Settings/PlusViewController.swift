//
//  PlusViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/20/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Kingfisher
import SafariServices
import SwiftyStoreKit
import Themeable
import UIKit

struct Contributor: Decodable {
    var id: Int
    var login: String
    var html_url: String
    var avatar_url: String

    var avatarURL: URL {
        return URL(string: self.avatar_url)!
    }

    var profileURL: URL {
        return URL(string: self.html_url)!
    }
}

class PlusViewController: UIViewController {
    @IBOutlet weak var scrollContentHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var kindTipButton: UIButton!
    @IBOutlet weak var kindTipButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var kindTipSpinner: UIActivityIndicatorView!

    @IBOutlet weak var excellentTipButton: UIButton!
    @IBOutlet weak var excellentTipButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var excellentTipSpinner: UIActivityIndicatorView!

    @IBOutlet weak var incredibleTipButton: UIButton!
    @IBOutlet weak var incredibleTipButtonWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var incredibleTipSpinner: UIActivityIndicatorView!

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var gianniImageView: UIImageView!
    @IBOutlet weak var pichImageView: UIImageView!

    @IBOutlet var titleLabels: [UILabel]!
    @IBOutlet var detailLabels: [UILabel]!
    @IBOutlet var imageViews: [UIImageView]!

    var loadingBarButton: UIBarButtonItem!
    var restoreBarButton: UIBarButtonItem!

    let kindTipId = "com.tortugapower.audiobookplayer.tip.kind"
    let excellentTipId = "com.tortugapower.audiobookplayer.tip.excellent"
    let incredibleTipId = "com.tortugapower.audiobookplayer.tip.incredible"

    //constants for button animations
    let defaultTipButtonsWidth: CGFloat = 60.0

    //constants for collectionView layout
    let sectionInsets = UIEdgeInsets(top: 0.0, left: 10.0, bottom: 25.0, right: 0.0)
    let cellHeight = 35

    // Maintainers
    let contributorGianni = Contributor(id: 14112819,
                                        login: "GianniCarlo",
                                        html_url: "https://github.com/GianniCarlo",
                                        avatar_url: "https://avatars2.githubusercontent.com/u/14112819?v=4")
    let contributorPichfl = Contributor(id: 194641,
                                        login: "pichfl",
                                        html_url: "https://github.com/pichfl",
                                        avatar_url: "https://avatars2.githubusercontent.com/u/194641?v=4")

    var contributors = [Contributor]() {
        didSet {
            // Resize scroll content height
            let rows = Double(self.contributors.count) / 5
            let collectionheight = CGFloat(Int(rows.rounded(.up)) * self.cellHeight) + self.sectionInsets.bottom

            self.collectionViewHeightConstraint.constant = collectionheight
            self.scrollContentHeightConstraint.constant = collectionheight + self.collectionView.frame.origin.y

            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
                self.collectionView.reloadSections(IndexSet(integer: 0))
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.gianniImageView.kf.setImage(with: self.contributorGianni.avatarURL)
        self.pichImageView.kf.setImage(with: self.contributorPichfl.avatarURL)

        let activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        activityIndicatorView.startAnimating()
        self.loadingBarButton = UIBarButtonItem(customView: activityIndicatorView)

        self.setupContributors()

        setUpTheming()
    }

    func setupSpinners() {
        self.kindTipSpinner.stopAnimating()
        self.excellentTipSpinner.stopAnimating()
        self.incredibleTipSpinner.stopAnimating()
    }

    func setupContributors() {
        let url = URL(string: "https://api.github.com/repos/TortugaPower/BookPlayer/contributors")!
        let task = URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                let contributors = try? JSONDecoder().decode([Contributor].self, from: data) else { return }

            DispatchQueue.main.async {
                self.contributors = contributors.filter({ (contributor) -> Bool in
                    contributor.id != self.contributorGianni.id && contributor.id != self.contributorPichfl.id
                })
            }
        }

        task.resume()
    }

    @IBAction func close(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func restorePurchases(_ sender: UIBarButtonItem) {
        self.restoreBarButton = self.navigationItem.rightBarButtonItem
        self.navigationItem.rightBarButtonItem = self.loadingBarButton

        SwiftyStoreKit.restorePurchases(atomically: true) { results in
            self.navigationItem.rightBarButtonItem = self.restoreBarButton

            if results.restoreFailedPurchases.count > 0 {
                self.showAlert("Network Error", message: "Please try again later")
            } else if results.restoredPurchases.count > 0 {
                self.showAlert("BookPlayer Plus restored!", message: nil)
                UserDefaults.standard.set(true, forKey: Constants.UserDefaults.donationMade.rawValue)
                NotificationCenter.default.post(name: .donationMade, object: nil)
            } else {
                self.showAlert("You haven't tipped us yet", message: nil)
            }
        }
    }

    @IBAction func showGianniProfile(_ sender: UIButton) {
        self.showProfile(self.contributorGianni.profileURL)
    }

    @IBAction func showPichProfile(_ sender: UIButton) {
        self.showProfile(self.contributorPichfl.profileURL)
    }

    @IBAction func kindTipPressed(_ sender: UIButton) {
        self.requestProduct(self.kindTipId, sender: sender)
    }

    @IBAction func excellentTipPressed(_ sender: UIButton) {
        self.requestProduct(self.excellentTipId, sender: sender)
    }

    @IBAction func incredibleTipPressed(_ sender: UIButton) {
        self.requestProduct(self.incredibleTipId, sender: sender)
    }

    func hideAllSpinners() {
        self.showSpinner(false, sender: self.kindTipButton)
        self.showSpinner(false, sender: self.excellentTipButton)
        self.showSpinner(false, sender: self.incredibleTipButton)
    }

    func showSpinner(_ flag: Bool, sender: UIButton) {
        var spinner: UIActivityIndicatorView!
        var widthConstraint: NSLayoutConstraint!

        switch sender {
        case self.kindTipButton:
            spinner = self.kindTipSpinner
            widthConstraint = self.kindTipButtonWidthConstraint
        case self.excellentTipButton:
            spinner = self.excellentTipSpinner
            widthConstraint = self.excellentTipButtonWidthConstraint
        default:
            spinner = self.incredibleTipSpinner
            widthConstraint = self.incredibleTipButtonWidthConstraint
        }

        if flag {
            spinner.startAnimating()
            widthConstraint.constant = spinner.bounds.width
            spinner.color = sender.backgroundColor
        } else {
            spinner.stopAnimating()
            widthConstraint.constant = self.defaultTipButtonsWidth
        }

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
            sender.alpha = flag ? 0.0 : 1.0
        }
    }

    func showProfile(_ url: URL) {
        let safari = SFSafariViewController(url: url)

        if #available(iOS 11.0, *) {
            safari.dismissButtonStyle = .close
        }

        self.present(safari, animated: true)
    }

    func requestProduct(_ id: String, sender: UIButton) {
        self.showSpinner(true, sender: sender)

        SwiftyStoreKit.purchaseProduct(id, quantity: 1, atomically: true) { result in
            self.showSpinner(false, sender: sender)

            switch result {
            case .success(let purchase):
                print("Purchase Success: \(purchase.productId)")
                UserDefaults.standard.set(true, forKey: Constants.UserDefaults.donationMade.rawValue)
                NotificationCenter.default.post(name: .donationMade, object: nil)
            case .error(let error):
                guard error.code != .paymentCancelled else { return }

                self.showAlert("Error", message: (error as NSError).localizedDescription)
            }
        }
    }
}

extension PlusViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.contributors.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // swiftlint:disable force_cast
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ContributorViewCell", for: indexPath) as! ContributorCellView
        // swiftlint:enable force_cast

        let contributor = self.contributors[indexPath.item]

        cell.imageView.kf.setImage(with: contributor.avatarURL)

        return cell
    }
}

extension PlusViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let contributor = self.contributors[indexPath.item]

        self.showProfile(contributor.profileURL)
    }
}

extension PlusViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.cellHeight, height: self.cellHeight)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        return self.sectionInsets
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return self.sectionInsets.left
    }
}

extension PlusViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.view.backgroundColor = theme.settingsBackgroundColor

        for label in self.titleLabels {
            label.textColor = theme.primaryColor
        }

        for label in self.detailLabels {
            label.textColor = theme.detailColor
        }

        for image in self.imageViews {
            image.tintColor = theme.highlightColor
        }
    }
}
