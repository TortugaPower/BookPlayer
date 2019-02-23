//
//  PlusViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/20/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Kingfisher
import SafariServices
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

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var collectionViewHeightConstraint: NSLayoutConstraint!

    @IBOutlet weak var gianniImageView: UIImageView!
    @IBOutlet weak var pichImageView: UIImageView!

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

        self.setupContributors()

        setUpTheming()
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

    func showProfile(_ url: URL) {
        let safari = SFSafariViewController(url: url)

        if #available(iOS 11.0, *) {
            safari.dismissButtonStyle = .close
        }

        self.present(safari, animated: true)
    }

    @IBAction func showGianniProfile(_ sender: UIButton) {
        self.showProfile(self.contributorGianni.profileURL)
    }

    @IBAction func showPichProfile(_ sender: UIButton) {
        self.showProfile(self.contributorPichfl.profileURL)
    }

    @IBAction func kindTipPressed(_ sender: UIButton) {}

    @IBAction func excellentTipPressed(_ sender: UIButton) {}

    @IBAction func incredibleTipPressed(_ sender: UIButton) {}
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
    }
}
