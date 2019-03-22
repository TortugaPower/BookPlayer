//
//  IconsViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/19/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class IconsViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var bannerView: PlusBannerView!
    @IBOutlet weak var bannerHeightConstraint: NSLayoutConstraint!

    var icons = DataManager.getIcons()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 1))

        if !UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue) {
            NotificationCenter.default.addObserver(self, selector: #selector(self.donationMade), name: .donationMade, object: nil)
        } else {
            self.donationMade()
        }

        setUpTheming()
    }

    @objc func donationMade() {
        self.bannerView.isHidden = true
        self.bannerHeightConstraint.constant = 0
        self.tableView.reloadData()
    }

    func changeIcon(to iconName: String) {
        guard UIApplication.shared.supportsAlternateIcons else {
            return
        }

        UserDefaults.standard.set(iconName, forKey: Constants.UserDefaults.appIcon.rawValue)

        let icon = iconName == "Default" ? nil : iconName

        UIApplication.shared.setAlternateIconName(icon, completionHandler: { error in
            guard error != nil else { return }

            self.showAlert("Error", message: "Changing the app icon wasn't successful. Try again later")
        })
    }
}

extension IconsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.icons.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // swiftlint:disable force_cast
        let cell = tableView.dequeueReusableCell(withIdentifier: "IconCellView", for: indexPath) as! IconCellView
        // swiftlint:enable force_cast

        let item = self.icons[indexPath.row]

        cell.titleLabel.text = item.title
        cell.authorLabel.text = item.author
        cell.iconImage = UIImage(named: item.imageName)
        cell.isLocked = item.isLocked && !UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue)

        let currentAppIcon = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue) ?? "Default"

        cell.accessoryType = item.id == currentAppIcon
            ? .checkmark
            : .none

        return cell
    }
}

extension IconsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? IconCellView else { return }

        defer {
            tableView.reloadData()
        }

        guard !cell.isLocked else {
            return
        }

        let item = self.icons[indexPath.row]

        self.changeIcon(to: item.id)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }
}

extension IconsViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.view.backgroundColor = theme.settingsBackgroundColor

        self.tableView.backgroundColor = theme.settingsBackgroundColor
        self.tableView.separatorColor = theme.separatorColor
    }
}
