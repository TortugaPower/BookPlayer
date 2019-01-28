//
//  ThemesViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/19/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class ThemesViewController: UIViewController {
    @IBOutlet weak var defaultThemesTableView: UITableView!
    @IBOutlet weak var extraThemesTableView: UITableView!
    @IBOutlet weak var extraThemesLabel: UILabel!
    @IBOutlet weak var separatorView: UIView!

    var defaultThemes: [Theme]!
    var extraThemes: [Theme]!

    override func viewDidLoad() {
        super.viewDidLoad()

        DataManager.reloadThemes(in: ThemeManager.shared.library)

        self.defaultThemes = Array(ThemeManager.shared.availableThemes[...1])
        self.extraThemes = Array(ThemeManager.shared.availableThemes[2...])

        setUpTheming()

        self.extraThemesTableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.extraThemesTableView.frame.size.width, height: 1))
    }

    func extractTheme() {
        let vc = ItemSelectionViewController()

        guard let books = DataManager.getBooks() else { return }
        vc.items = books
        vc.onItemSelected = { selectedItem in
            guard let book = selectedItem as? Book else { return }

            let theme = ThemeManager.shared.availableThemes.first(where: { (theme) -> Bool in
                theme.sameColors(as: book.artworkColors)
            })

            if theme == nil {
                self.extraThemes.append(book.artworkColors)
                ThemeManager.shared.library.addToAvailableThemes(book.artworkColors)
                DataManager.saveContext()
            }

            ThemeManager.shared.currentTheme = theme ?? book.artworkColors

            self.extraThemesTableView.reloadData()
        }

        let nav = AppNavigationController(rootViewController: vc)
        self.present(nav, animated: true) {
            self.extraThemesTableView.reloadData()
        }
    }
}

extension ThemesViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableView == self.defaultThemesTableView
            ? 1
            : Section.total.rawValue
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == Section.data.rawValue else {
            return 1
        }

        return tableView == self.defaultThemesTableView
            ? self.defaultThemes.count
            : self.extraThemes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // swiftlint:disable force_cast
        let cell = tableView.dequeueReusableCell(withIdentifier: "ThemeCell", for: indexPath) as! ThemeCellView
        // swiftlint:enable force_cast

        cell.showCaseLabel.isHidden = false

        guard indexPath.sectionValue != .add else {
            cell.titleLabel.text = "Add"
            cell.titleLabel.textColor = ThemeManager.shared.currentTheme.tertiary
            cell.plusImageView.isHidden = false
            cell.plusImageView.tintColor = ThemeManager.shared.currentTheme.tertiary
            cell.showCaseLabel.isHidden = true

            cell.showCaseLabel.backgroundColor = ThemeManager.shared.currentTheme.background
            cell.showCaseLabel.textColor = ThemeManager.shared.currentTheme.tertiary
            cell.showCaseLabel.layer.borderColor = UIColor.clear.cgColor
            return cell
        }

        let item = tableView == self.defaultThemesTableView
            ? self.defaultThemes[indexPath.row]
            : self.extraThemes[indexPath.row]

        cell.titleLabel.text = item.title
        cell.showCaseLabel.backgroundColor = item.background
        cell.showCaseLabel.textColor = item.primary
        cell.showCaseLabel.layer.borderColor = item.secondary.cgColor

        cell.accessoryType = item == ThemeManager.shared.currentTheme
            ? .checkmark
            : .none

        return cell
    }
}

extension ThemesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.sectionValue != .add else {
            self.extractTheme()
            return
        }

        let item = tableView == self.defaultThemesTableView
            ? self.defaultThemes[indexPath.row]
            : self.extraThemes[indexPath.row]

        ThemeManager.shared.currentTheme = item
    }
}

extension ThemesViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.view.backgroundColor = theme.background
        self.defaultThemesTableView.backgroundColor = theme.background
        self.extraThemesTableView.backgroundColor = theme.background
        self.extraThemesLabel.textColor = theme.secondary
        self.separatorView.backgroundColor = theme.secondary
        self.defaultThemesTableView.reloadData()
        self.extraThemesTableView.reloadData()
    }
}
