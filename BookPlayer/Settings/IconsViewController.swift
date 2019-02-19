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
    var icons = DataManager.getIcons()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 1))

        setUpTheming()
    }

    func changeIcon(to iconName: String) {
        guard UIApplication.shared.supportsAlternateIcons else {
            return
        }

        UserDefaults.standard.set(iconName, forKey: Constants.UserDefaults.appIcon.rawValue)

        let icon = iconName == "Default" ? nil : iconName

        UIApplication.shared.setAlternateIconName(icon, completionHandler: { error in
            // 3
            if let error = error {
                print("App icon failed to change due to \(error.localizedDescription)")
            } else {
                print("App icon changed successfully")
            }
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
        cell.iconImageView.image = UIImage(named: item.imageName)

        let currentAppIcon = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue) ?? "Default"

        cell.accessoryType = item.id == currentAppIcon
            ? .checkmark
            : .none

        return cell
    }
}

extension IconsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = self.icons[indexPath.row]
        self.changeIcon(to: item.id)
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 86
    }
}

extension IconsViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.view.backgroundColor = theme.settingsBackgroundColor

        self.tableView.backgroundColor = theme.backgroundColor
        self.tableView.separatorColor = theme.separatorColor
    }
}
