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
    @IBOutlet var separatorViews: [UIView]!

    var scrolledToCurrentTheme = false
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

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        guard !self.scrolledToCurrentTheme,
            let index = self.extraThemes.firstIndex(of: ThemeManager.shared.currentTheme) else { return }

        self.scrolledToCurrentTheme = true
        let indexPath = IndexPath(row: index, section: 0)
        self.extraThemesTableView.scrollToRow(at: indexPath, at: .top, animated: false)
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
        cell.accessoryType = .none
        cell.titleLabel.textColor = ThemeManager.shared.currentTheme.primaryColor

        guard indexPath.sectionValue != .add else {
            cell.titleLabel.text = "Add"
            cell.titleLabel.textColor = ThemeManager.shared.currentTheme.highlightColor
            cell.plusImageView.isHidden = false
            cell.plusImageView.tintColor = ThemeManager.shared.currentTheme.highlightColor
            cell.showCaseLabel.isHidden = true

            cell.showCaseLabel.backgroundColor = ThemeManager.shared.currentTheme.backgroundColor
            cell.showCaseLabel.textColor = ThemeManager.shared.currentTheme.highlightColor
            cell.showCaseLabel.layer.borderColor = UIColor.clear.cgColor
            return cell
        }

        let item = tableView == self.defaultThemesTableView
            ? self.defaultThemes[indexPath.row]
            : self.extraThemes[indexPath.row]

        cell.titleLabel.text = item.title
        cell.showCaseLabel.backgroundColor = item.backgroundColor
        cell.showCaseLabel.textColor = item.primaryColor
        cell.showCaseLabel.layer.borderColor = item.detailColor.cgColor

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
        self.view.backgroundColor = theme.settingsBackgroundColor
        self.defaultThemesTableView.backgroundColor = theme.backgroundColor
        self.defaultThemesTableView.separatorColor = theme.separatorColor
        self.extraThemesTableView.backgroundColor = theme.backgroundColor
        self.extraThemesTableView.separatorColor = theme.separatorColor
        self.extraThemesLabel.textColor = theme.detailColor
        self.separatorViews.forEach { separatorView in
            separatorView.backgroundColor = theme.separatorColor
        }
        self.defaultThemesTableView.reloadData()
        self.extraThemesTableView.reloadData()
    }
}
