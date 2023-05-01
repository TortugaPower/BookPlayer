//
//  IconsViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/19/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit
import WidgetKit

class IconsViewController: UIViewController, Storyboarded {
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var bannerView: PlusBannerView!
  @IBOutlet weak var bannerHeightConstraint: NSLayoutConstraint!

  let userDefaults = UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)
  var icons: [Icon]!

  var viewModel: IconsViewModel!
  private var disposeBag = Set<AnyCancellable>()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "settings_app_icon_title".localized
    self.navigationItem.leftBarButtonItem = UIBarButtonItem(
      image: ImageIcons.navigationBackImage,
      style: .plain,
      target: self,
      action: #selector(self.didPressClose)
    )

    self.icons = self.getIcons()

    self.tableView.tableFooterView = UIView(frame: CGRect(x: 0, y: 0, width: self.tableView.frame.size.width, height: 1))

    self.handleDonationObserver()

    setUpTheming()

    self.bannerView.showPlus = { [weak self] in
      self?.viewModel.showPro()
    }
  }

  func handleDonationObserver() {
    if self.viewModel.hasMadeDonation() {
      self.donationMade()
    } else {
      self.viewModel.$account
        .receive(on: RunLoop.main)
        .sink { [weak self] account in
        if account?.donationMade ?? false {
          self?.donationMade()
        }
      }
      .store(in: &disposeBag)
    }
  }

  @objc func didPressClose() {
    self.dismiss(animated: true, completion: nil)
  }

    @objc func donationMade() {
        self.bannerView.isHidden = true
        self.bannerHeightConstraint.constant = 0
        self.tableView.reloadData()
    }

    func getIcons() -> [Icon] {
        guard
            let iconsFile = Bundle.main.url(forResource: "Icons", withExtension: "json"),
            let data = try? Data(contentsOf: iconsFile, options: .mappedIfSafe),
            let icons = try? JSONDecoder().decode([Icon].self, from: data)
        else { return [] }

        return icons
    }

    func changeIcon(to iconName: String) {
        guard UIApplication.shared.supportsAlternateIcons else {
            return
        }

        self.userDefaults?.set(iconName, forKey: Constants.UserDefaults.appIcon.rawValue)

        let icon = iconName == "Default" ? nil : iconName

        UIApplication.shared.setAlternateIconName(icon, completionHandler: { error in
          WidgetCenter.shared.reloadAllTimelines()

          guard error != nil else { return }

          self.showAlert("error_title".localized, message: "icon_error_description".localized)
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
        cell.isLocked = item.isLocked && !self.viewModel.hasMadeDonation()

        let currentAppIcon = self.userDefaults?.string(forKey: Constants.UserDefaults.appIcon.rawValue) ?? "Default"

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
    func applyTheme(_ theme: SimpleTheme) {
        self.view.backgroundColor = theme.systemGroupedBackgroundColor

        self.tableView.backgroundColor = theme.systemGroupedBackgroundColor
        self.tableView.separatorColor = theme.separatorColor
    }
}
