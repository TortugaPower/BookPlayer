//
//  ThemesViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/19/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit
import WidgetKit

class ThemesViewController: UIViewController, Storyboarded {
    @IBOutlet var brightnessViews: [UIView]!
    @IBOutlet weak var brightnessContainerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var brightnessDescriptionLabel: UILabel!
    @IBOutlet weak var brightnessSwitch: UISwitch!
    @IBOutlet weak var brightnessSlider: UISlider!
    @IBOutlet weak var brightnessPipView: UIImageView!
    @IBOutlet weak var sunImageView: UIImageView!
    @IBOutlet weak var sunLeadingConstraint: NSLayoutConstraint!

    @IBOutlet weak var systemModeSwitch: UISwitch!
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

    var viewModel: ThemesViewModel!
    private var disposeBag = Set<AnyCancellable>()
    var shouldRefreshTableHeight = true
    let cellHeight = 45
    let expandedHeight = 110

    var localThemes: [SimpleTheme]! {
        didSet {
            self.localThemesTableHeightConstraint.constant = CGFloat(self.localThemes.count * self.cellHeight)
        }
    }

    var extractedThemes: [SimpleTheme]!

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "themes_title".localized
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      image: ImageIcons.navigationBackImage,
      style: .plain,
      target: self,
      action: #selector(self.didPressClose)
    )
    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      title: "restore_title".localized,
      style: .plain,
      target: self,
      action: #selector(self.didPressRestore)
    )

    self.localThemes = ThemeManager.getLocalThemes()
    self.extractedThemes = [] // disabled

    self.handleDonationObserver()

    setUpTheming()

    self.extractedThemesTableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.extractedThemesTableView.frame.size.width, height: 1))

    self.darkModeSwitch.isOn = UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeDarkVariantEnabled.rawValue)
    self.systemModeSwitch.isOn = UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue)
    self.brightnessSwitch.isOn = UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeBrightnessEnabled.rawValue)
    self.brightnessSlider.value = UserDefaults.standard.float(forKey: Constants.UserDefaults.themeBrightnessThreshold.rawValue)

    if self.brightnessSwitch.isOn {
      self.toggleAutomaticBrightness(animated: false)
    }

    if self.systemModeSwitch.isOn {
      self.brightnessSwitch.isEnabled = false
      self.darkModeSwitch.isEnabled = false
    }

    self.brightnessChanged()

    NotificationCenter.default.addObserver(self, selector: #selector(self.brightnessChanged), name: UIScreen.brightnessDidChangeNotification, object: nil)

    self.bannerView.showPlus = { [weak self] in
      self?.viewModel.showPro()
    }

    bindDataItems()
  }

  func bindDataItems() {
    self.viewModel.observeEvents()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] event in
        switch event {
        case .showAlert(let content):
          self?.showAlert(content)
        case .showLoader(let flag):
          self?.showLoader(flag)
        case .donationMade:
          self?.donationMade()
        }
      }
      .store(in: &disposeBag)
  }

  func showLoader(_ flag: Bool) {
    if flag {
      LoadingUtils.loadAndBlock(in: self)
    } else {
      LoadingUtils.stopLoading(in: self)
    }
  }

  func handleDonationObserver() {
    if self.viewModel.hasSubscription {
      self.donationMade()
    } else {
      self.viewModel.$account
        .receive(on: RunLoop.main)
        .sink { [weak self] account in
        if account?.hasSubscription ?? false {
          self?.donationMade()
        }
      }
      .store(in: &disposeBag)
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    guard
      shouldRefreshTableHeight,
      let firstCell = localThemesTableView.visibleCells.first
    else { return }

    shouldRefreshTableHeight = false

    var tableHeight = CGFloat(self.localThemes.count) * firstCell.bounds.height

    if self.brightnessSwitch.isOn {
      tableHeight += CGFloat(self.cellHeight)
    }

    self.localThemesTableHeightConstraint.constant = tableHeight
    self.scrollContentHeightConstraint.constant = tableHeight + self.localThemesTableView.frame.origin.y
  }

  @objc func donationMade() {
    if self.viewModel.hasSubscription {
      self.bannerView.isHidden = true
      self.bannerHeightConstraint.constant = 30
    }
    self.localThemesTableView.reloadData()
    self.extractedThemesTableView.reloadData()
  }

  func extractTheme() {}

  @objc func didPressClose() {
    self.dismiss(animated: true, completion: nil)
  }

  @objc func didPressRestore() {
    viewModel.handleRestorePurchases()
  }

    @IBAction func sliderUpdated(_ sender: UISlider) {
        let lowerBounds: Float = 0.22
        let upperBounds: Float = 0.27

        if (lowerBounds...upperBounds).contains(sender.value) {
            sender.setValue(0.25, animated: false)
        }

        UserDefaults.standard.set(sender.value, forKey: Constants.UserDefaults.themeBrightnessThreshold.rawValue)
    }

    @IBAction func sliderUp(_ sender: UISlider) {
        let brightness = (UIScreen.main.brightness * 100).rounded() / 100
        let shouldUseDarkVariant = brightness <= CGFloat(sender.value)

        if shouldUseDarkVariant != ThemeManager.shared.useDarkVariant {
            ThemeManager.shared.useDarkVariant = shouldUseDarkVariant
        }
    }

    @objc private func brightnessChanged() {
        let brightness = (UIScreen.main.brightness * 100).rounded() / 100

        self.sunLeadingConstraint.constant = (brightness * self.brightnessSlider.bounds.width) - (self.sunImageView.bounds.width / 2)
    }

    @IBAction func toggleSystemMode(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue)
        self.brightnessSwitch.isEnabled = !sender.isOn
        self.darkModeSwitch.isEnabled = !sender.isOn

        guard !sender.isOn else {
            ThemeManager.shared.checkSystemMode()
            return
        }

        // handle switching variant if the other toggle is enabled
        let darkVariantEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeDarkVariantEnabled.rawValue)

        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeBrightnessEnabled.rawValue) {
            self.sliderUp(self.brightnessSlider)
        } else if ThemeManager.shared.useDarkVariant != darkVariantEnabled {
            ThemeManager.shared.useDarkVariant = darkVariantEnabled
        }
    }

    @IBAction func toggleDarkMode(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.UserDefaults.themeDarkVariantEnabled.rawValue)
        ThemeManager.shared.useDarkVariant = sender.isOn
    }

    @IBAction func toggleAutomaticBrightness(_ sender: UISwitch) {
        UserDefaults.standard.set(sender.isOn, forKey: Constants.UserDefaults.themeBrightnessEnabled.rawValue)
        self.toggleAutomaticBrightness(animated: true)
        self.sliderUp(self.brightnessSlider)

        guard !sender.isOn else { return }
        // handle switching variant if the other toggle is enabled
        let darkVariantEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeDarkVariantEnabled.rawValue)

        guard ThemeManager.shared.useDarkVariant != darkVariantEnabled else { return }

        ThemeManager.shared.useDarkVariant = darkVariantEnabled
    }

    func toggleAutomaticBrightness(animated: Bool) {
        self.brightnessContainerHeightConstraint.constant = self.brightnessSwitch.isOn
            ? CGFloat(self.expandedHeight)
            : CGFloat(self.cellHeight)

        shouldRefreshTableHeight = true

        guard animated else {
            self.brightnessViews.forEach { view in
                view.alpha = self.brightnessSwitch.isOn
                    ? 1.0
                    : 0.0
            }
          self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
            return
        }

        UIView.animate(withDuration: 0.3, animations: {
            self.brightnessViews.forEach { view in
                view.alpha = self.brightnessSwitch.isOn
                    ? 1.0
                    : 0.0
            }
          self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
}

extension ThemesViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableView == self.localThemesTableView
            ? 1
            : BPSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard section == BPSection.data.rawValue else {
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
            cell.titleLabel.text = "library_add_button".localized
            cell.titleLabel.textColor = ThemeManager.shared.currentTheme.linkColor
            cell.plusImageView.isHidden = false
            cell.plusImageView.tintColor = ThemeManager.shared.currentTheme.linkColor
            cell.showCaseView.isHidden = true
            cell.isLocked = !self.viewModel.hasMadeDonation()
            return cell
        }

        let item = tableView == self.localThemesTableView
            ? self.localThemes[indexPath.row]
            : self.extractedThemes[indexPath.row]

        cell.titleLabel.text = item.title
        cell.setupShowCaseView(for: item)
        cell.isLocked = item.locked && !self.viewModel.hasMadeDonation()

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

        WidgetCenter.shared.reloadAllTimelines()
    }
}

extension ThemesViewController: Themeable {
    func applyTheme(_ theme: SimpleTheme) {
        self.view.backgroundColor = theme.systemGroupedBackgroundColor

        self.localThemesTableView.backgroundColor = theme.systemBackgroundColor
        self.localThemesTableView.separatorColor = theme.separatorColor
        self.extractedThemesTableView.backgroundColor = theme.systemBackgroundColor
        self.extractedThemesTableView.separatorColor = theme.separatorColor

        self.brightnessSlider.minimumTrackTintColor = theme.linkColor
        self.brightnessSlider.maximumTrackTintColor = theme.separatorColor
        self.brightnessDescriptionLabel.textColor = theme.secondaryColor

        self.sunImageView.tintColor = theme.separatorColor
        self.brightnessPipView.tintColor = theme.separatorColor

        self.sectionHeaderLabels.forEach { label in
            label.textColor = theme.secondaryColor
        }
        self.separatorViews.forEach { separatorView in
            separatorView.backgroundColor = theme.separatorColor
        }
        self.containerViews.forEach { view in
            view.backgroundColor = theme.systemBackgroundColor
        }
        self.titleLabels.forEach { label in
            label.textColor = theme.primaryColor
        }
        self.localThemesTableView.reloadData()
        self.extractedThemesTableView.reloadData()
    }
}
