//
//  PlusViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/20/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

struct Contributor {
    var name: String
    var avatar: String
}

class PlusViewController: UIViewController {
    @IBOutlet weak var collectionView: UICollectionView!

    @IBOutlet weak var gianniImageView: UIImageView!
    @IBOutlet weak var pichImageView: UIImageView!

    //constants for collectionView layout
    let sectionInsets = UIEdgeInsets(top: 0.0, left: 10.0, bottom: 25.0, right: 0.0)
    let itemsPerRow: CGFloat = 5

    var contributors = [Contributor]()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.contributors.append(Contributor(name: "", avatar: ""))
        self.contributors.append(Contributor(name: "", avatar: ""))
        self.contributors.append(Contributor(name: "", avatar: ""))
        self.contributors.append(Contributor(name: "", avatar: ""))
        self.contributors.append(Contributor(name: "", avatar: ""))
        self.contributors.append(Contributor(name: "", avatar: ""))
        self.contributors.append(Contributor(name: "", avatar: ""))
        self.contributors.append(Contributor(name: "", avatar: ""))

        setUpTheming()
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
        let contributor = self.contributors[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ContributorViewCell", for: indexPath)

        return cell
    }
}

extension PlusViewController: UICollectionViewDelegate {}

extension PlusViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 35, height: 35)
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
