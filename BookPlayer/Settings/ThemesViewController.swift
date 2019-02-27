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
    @IBOutlet weak var sunImageView: UIImageView!

    @IBOutlet weak var darkModeSwitch: UISwitch!

    @IBOutlet weak var localThemesTableView: UITableView!
    @IBOutlet weak var localThemesTableHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var extractedThemesTableView: UITableView!
    @IBOutlet weak var extractedThemesTableHeightConstraint: NSLayoutConstraint!

    @IBOutlet var containerViews: [UIView]!
    @IBOutlet var sectionHeaderLabels: [UILabel]!
    @IBOutlet var titleLabels: [UILabel]!
    @IBOutlet var separatorViews: [UIView]!

    @IBOutlet weak var scrollContentHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var bannerView: PlusBannerView!
    @IBOutlet weak var bannerHeightConstraint: NSLayoutConstraint!

    var scrolledToCurrentTheme = false
    let cellHeight = 44
    let expandedHeight = 110

    var localThemes: [Theme]! {
        didSet {
            self.localThemesTableHeightConstraint.constant = CGFloat(self.localThemes.count * self.cellHeight) + CGFloat(self.localThemes.count)
        }
    }

    var extractedThemes: [Theme]! {
        didSet {
            self.resizeScrollContent()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.localThemes = DataManager.getLocalThemes()
        self.extractedThemes = DataManager.getExtractedThemes()

        if !UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue) {
            NotificationCenter.default.addObserver(self, selector: #selector(self.donationMade), name: .donationMade, object: nil)
        } else {
            self.donationMade()
        }

        setUpTheming()

        self.extractedThemesTableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.extractedThemesTableView.frame.size.width, height: 1))

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
            let index = self.extractedThemes.firstIndex(of: ThemeManager.shared.currentTheme) else { return }

        self.scrolledToCurrentTheme = true
        let indexPath = IndexPath(row: index, section: 0)
        self.extractedThemesTableView.scrollToRow(at: indexPath, at: .top, animated: false)
    }

    @objc func donationMade() {
        self.bannerView.isHidden = true
        self.bannerHeightConstraint.constant = 30
        self.localThemesTableView.reloadData()
        self.extractedThemesTableView.reloadData()
    }

    func extractTheme() {
        let vc = ItemSelectionViewController()

        guard let books = DataManager.getBooks() else { return }

        vc.items = books
        vc.onItemSelected = { selectedItem in
            guard let book = selectedItem as? Book else { return }

            let theme = self.extractedThemes.first(where: { (theme) -> Bool in
                theme.sameColors(as: book.artworkColors)
            })

            if theme == nil {
                self.extractedThemes.append(book.artworkColors)
                DataManager.addExtractedTheme(book.artworkColors)
            }

            ThemeManager.shared.currentTheme = theme ?? book.artworkColors

            self.extractedThemesTableView.reloadData()
        }

        let nav = AppNavigationController(rootViewController: vc)
        self.present(nav, animated: true) {
            self.extractedThemesTableView.reloadData()
        }
    }

    @IBAction func sliderUpdated(_ sender: UISlider) {
        let lowerBounds: Float = 0.22
        let upperBounds: Float = 0.27

        if (lowerBounds...upperBounds).contains(sender.value) {
            sender.setValue(0.25, animated: false)
        }

        UserDefaults.standard.set(sender.value, forKey: Constants.UserDefaults.themeBrightnessThreshold.rawValue)
    }

    @IBAction func toggleDarkMode(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.UserDefaults.themeDarkVariantEnabled.rawValue)
        ThemeManager.shared.useDarkVariant = sender.isOn
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
        let tableHeight = CGFloat(self.extractedThemes.count * cellHeight + cellHeight)

        self.extractedThemesTableHeightConstraint.constant = tableHeight
        self.scrollContentHeightConstraint.constant = tableHeight + CGFloat(cellHeight) + self.extractedThemesTableView.frame.origin.y
    }
}

extension ThemesViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableView == self.localThemesTableView
            ? 1
            : Section.total.rawValue
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == Section.data.rawValue else {
            return 1
        }

        return tableView == self.localThemesTableView
            ? self.localThemes.count
            : self.extractedThemes.count
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
            cell.isLocked = !UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue)
            return cell
        }

        let item = tableView == self.localThemesTableView
            ? self.localThemes[indexPath.row]
            : self.extractedThemes[indexPath.row]

        cell.titleLabel.text = item.title
        cell.setupShowCaseView(for: item)
        cell.isLocked = item.locked && !UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue)

        cell.accessoryType = item == ThemeManager.shared.currentTheme
            ? .checkmark
            : .none

        return cell
    }
}

extension ThemesViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? ThemeCellView else { return }

        guard !cell.isLocked else {
            tableView.reloadData()
            return
        }

        guard indexPath.sectionValue != .add else {
            self.extractTheme()
            return
        }

        let item = tableView == self.localThemesTableView
            ? self.localThemes[indexPath.row]
            : self.extractedThemes[indexPath.row]

        ThemeManager.shared.currentTheme = item
    }
}

extension ThemesViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.view.backgroundColor = theme.settingsBackgroundColor

        self.localThemesTableView.backgroundColor = theme.backgroundColor
        self.localThemesTableView.separatorColor = theme.separatorColor
        self.extractedThemesTableView.backgroundColor = theme.backgroundColor
        self.extractedThemesTableView.separatorColor = theme.separatorColor

        self.brightnessSlider.minimumTrackTintColor = theme.highlightColor
        self.brightnessSlider.maximumTrackTintColor = theme.separatorColor
        self.brightnessDescriptionLabel.textColor = theme.detailColor
        self.sunImageView.tintColor = theme.separatorColor

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
        self.localThemesTableView.reloadData()
        self.extractedThemesTableView.reloadData()
    }
}
