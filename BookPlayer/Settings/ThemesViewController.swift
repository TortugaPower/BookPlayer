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
    @IBOutlet var brightnessViews: [UIView]!
    @IBOutlet weak var brightnessContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var brightnessDescriptionLabel: UILabel!
    @IBOutlet weak var brightnessSwitch: UISwitch!
    @IBOutlet weak var brightnessSlider: UISlider!

    @IBOutlet weak var darkModeSwitch: UISwitch!

    @IBOutlet weak var defaultThemesTableView: UITableView!
    @IBOutlet weak var defaultThemesTableHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var extraThemesTableView: UITableView!
    @IBOutlet weak var extraThemesTableHeightConstraint: NSLayoutConstraint!

    @IBOutlet var containerViews: [UIView]!
    @IBOutlet var sectionHeaderLabels: [UILabel]!
    @IBOutlet var titleLabels: [UILabel]!
    @IBOutlet var separatorViews: [UIView]!

    @IBOutlet weak var scrollContentHeightConstraint: NSLayoutConstraint!

    var scrolledToCurrentTheme = false
    let cellHeight = 44
    let expandedHeight = 110

    var defaultThemes: [Theme]! {
        didSet {
            self.defaultThemesTableHeightConstraint.constant = CGFloat(self.defaultThemes.count * self.cellHeight)
        }
    }

    var extraThemes: [Theme]! {
        didSet {
            self.resizeScrollContent()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        DataManager.reloadThemes(in: ThemeManager.shared.library)

        self.defaultThemes = Array(ThemeManager.shared.availableThemes[...1])
        self.extraThemes = Array(ThemeManager.shared.availableThemes[2...])

        setUpTheming()

        self.extraThemesTableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.extraThemesTableView.frame.size.width, height: 1))

        self.darkModeSwitch.isOn = UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeDarkVariantEnabled.rawValue)
        self.brightnessSwitch.isOn = UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeBrightnessEnabled.rawValue)
        self.brightnessSlider.value = UserDefaults.standard.float(forKey: Constants.UserDefaults.themeBrightnessThreshold.rawValue)

        if self.brightnessSwitch.isOn {
            self.toggleAutomaticBrightness(animated: false)
        }
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

    @IBAction func sliderUpdated(_ sender: UISlider) {
        UserDefaults.standard.set(sender.value, forKey: Constants.UserDefaults.themeBrightnessThreshold.rawValue)
    }

    @IBAction func toggleDarkMode(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.UserDefaults.themeDarkVariantEnabled.rawValue)
    }

    @IBAction func toggleAutomaticBrightness(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.UserDefaults.themeBrightnessEnabled.rawValue)
        self.toggleAutomaticBrightness(animated: true)
    }

    func toggleAutomaticBrightness(animated: Bool) {
        self.brightnessContainerHeightConstraint.constant = self.brightnessSwitch.isOn
            ? CGFloat(self.expandedHeight)
            : CGFloat(self.cellHeight)

        guard animated else {
            self.brightnessViews.forEach({ view in
                view.alpha = self.brightnessSwitch.isOn
                    ? 1.0
                    : 0.0
            })
            self.view.layoutIfNeeded()
            self.resizeScrollContent()
            return
        }

        UIView.animate(withDuration: 0.3, animations: {
            self.brightnessViews.forEach({ view in
                view.alpha = self.brightnessSwitch.isOn
                    ? 1.0
                    : 0.0
            })
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.resizeScrollContent()
        })
    }

    func resizeScrollContent() {
        // add a second cellHeight to account for the 'add' button
        let tableHeight = CGFloat(self.extraThemes.count * cellHeight + cellHeight)

        self.extraThemesTableHeightConstraint.constant = tableHeight
        self.scrollContentHeightConstraint.constant = tableHeight + self.extraThemesTableView.frame.origin.y
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

        cell.showCaseView.isHidden = false
        cell.accessoryType = .none
        cell.titleLabel.textColor = ThemeManager.shared.currentTheme.primaryColor

        guard indexPath.sectionValue != .add else {
            cell.titleLabel.text = "Add"
            cell.titleLabel.textColor = ThemeManager.shared.currentTheme.highlightColor
            cell.plusImageView.isHidden = false
            cell.plusImageView.tintColor = ThemeManager.shared.currentTheme.highlightColor
            cell.showCaseView.isHidden = true
            return cell
        }

        let item = tableView == self.defaultThemesTableView
            ? self.defaultThemes[indexPath.row]
            : self.extraThemes[indexPath.row]

        cell.titleLabel.text = item.title
        cell.setupShowCaseView(for: item)

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

        self.brightnessSlider.minimumTrackTintColor = theme.highlightColor
        self.brightnessSlider.maximumTrackTintColor = theme.lightHighlightColor
        self.brightnessDescriptionLabel.textColor = theme.detailColor

        self.sectionHeaderLabels.forEach { label in
            label.textColor = theme.detailColor
        }
        self.separatorViews.forEach { separatorView in
            separatorView.backgroundColor = theme.separatorColor
        }
        self.containerViews.forEach { view in
            view.backgroundColor = theme.backgroundColor
        }
        self.titleLabels.forEach { label in
            label.textColor = theme.primaryColor
        }
        self.defaultThemesTableView.reloadData()
        self.extraThemesTableView.reloadData()
    }
}
