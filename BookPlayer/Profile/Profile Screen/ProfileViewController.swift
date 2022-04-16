//
//  ProfileViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

class ProfileViewController: BaseTableViewController<ProfileCoordinator, ProfileViewModel>,
                             Storyboarded {
  @IBOutlet weak var containerProfileCardView: UIView!
  @IBOutlet weak var containerProfileImageView: UIView!
  @IBOutlet weak var profileImageView: UIImageView!
  @IBOutlet weak var signedInStatusLabel: UILabel!
  @IBOutlet weak var accountLabel: UILabel!
  @IBOutlet weak var chevronImageView: UIImageView!
  @IBOutlet weak var timeListenedValueLabel: UILabel!
  @IBOutlet weak var timeListenedTitleLabel: UILabel!

  @IBOutlet weak var hoursSavedValueLabel: UILabel!
  @IBOutlet weak var hoursSavedTitleLabel: UILabel!

  private var disposeBag = Set<AnyCancellable>()

  override func viewDidLoad() {
    super.viewDidLoad()

    setUpTheming()

    self.navigationItem.title = "Profile"

    self.bindObservers()
    self.setupViews()
  }

  func bindObservers() {
    self.viewModel.$account
      .receive(on: RunLoop.main)
      .sink { [weak self] account in
      self?.setupProfileCardView(account)
    }

    .store(in: &disposeBag)
  }

  func setupViews() {
    self.tableView.tableFooterView = UIView()
    self.containerProfileImageView.layer.masksToBounds = true
    self.containerProfileImageView.layer.cornerRadius = self.containerProfileImageView.frame.width / 2
    self.containerProfileCardView.layer.masksToBounds = true
    self.containerProfileCardView.layer.cornerRadius = 10
  }

  func setupProfileCardView(_ account: Account?) {
    if let account = account,
       !account.id.isEmpty {
      self.signedInStatusLabel.isHidden = true
      self.accountLabel.text = account.email
    } else {
      self.signedInStatusLabel.isHidden = false
      // TODO: localize
      self.accountLabel.text = "Set Up Account"
    }
  }

  @IBAction func didTapAccount(_ sender: UIButton) {
    self.viewModel.showAccount()
  }

  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    guard section == 0 else {
      return super.tableView(tableView, heightForHeaderInSection: section)
    }

    return CGFloat.leastNormalMagnitude
  }

  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return CGFloat.leastNormalMagnitude
  }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    guard section == 0 else {
      return super.tableView(tableView, titleForHeaderInSection: section)
    }

    return "settings_storage_title".localized
  }
}

// MARK: - Themeable

extension ProfileViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.tableView.backgroundColor = theme.systemBackgroundColor
    self.tableView.separatorColor = theme.systemBackgroundColor
    self.tableView.reloadData()

    self.containerProfileCardView.backgroundColor = theme.secondarySystemBackgroundColor
    self.accountLabel.textColor = theme.primaryColor
    self.signedInStatusLabel.textColor = theme.secondaryColor
    self.chevronImageView.tintColor = theme.secondaryColor
    self.containerProfileImageView.backgroundColor = theme.tertiarySystemBackgroundColor
    self.profileImageView.tintColor = theme.secondaryColor
    self.timeListenedValueLabel.textColor = theme.primaryColor
    self.timeListenedTitleLabel.textColor = theme.secondaryColor
    self.hoursSavedValueLabel.textColor = theme.primaryColor
    self.hoursSavedTitleLabel.textColor = theme.secondaryColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}
