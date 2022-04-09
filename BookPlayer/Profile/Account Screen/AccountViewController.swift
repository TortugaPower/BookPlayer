//
//  AccountViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class AccountViewController: BaseTableViewController<AccountCoordinator, AccountViewModel>,
                             Storyboarded {
  @IBOutlet weak var containerProfileCardView: UIView!
  @IBOutlet weak var containerProfileImageView: UIView!
  @IBOutlet weak var profileImageView: UIImageView!
  @IBOutlet weak var accountLabel: UILabel!
  @IBOutlet weak var proLabel: UILabel!
  @IBOutlet weak var costLabel: UILabel!
  @IBOutlet var imageViews: [UIView]!
  @IBOutlet weak var imageOverlayView: UIView!
  @IBOutlet weak var completeAccountButton: UIButton!
  @IBOutlet var secondaryLabels: [UILabel]!

  override func viewDidLoad() {
    super.viewDidLoad()

    setUpTheming()

    self.navigationItem.title = "Account"

    self.tableView.tableFooterView = UIView()

    self.completeAccountButton.layer.masksToBounds = true
    self.completeAccountButton.layer.cornerRadius = 5
    self.imageOverlayView.layer.masksToBounds = true
    self.imageOverlayView.layer.cornerRadius = 10

    setup()
  }

  func setup() {
    self.containerProfileImageView.layer.masksToBounds = true
    self.containerProfileImageView.layer.cornerRadius = self.containerProfileImageView.frame.width / 2
    self.containerProfileCardView.layer.masksToBounds = true
    self.containerProfileCardView.layer.cornerRadius = 10
  }

  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return CGFloat.leastNormalMagnitude
  }

  @IBAction func didPressClose(_ sender: UIBarButtonItem) {
    self.viewModel.dismiss()
  }

  @IBAction func didPressCompleteAccount(_ sender: UIButton) {
    self.viewModel.showCompleteAccount()
  }
}

// MARK: - Themeable

extension AccountViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.tableView.backgroundColor = theme.secondarySystemBackgroundColor
    self.tableView.separatorColor = theme.separatorColor
    self.tableView.reloadData()

    self.containerProfileCardView.backgroundColor = theme.secondarySystemBackgroundColor
    self.accountLabel.textColor = theme.primaryColor
    self.containerProfileImageView.backgroundColor = theme.tertiarySystemBackgroundColor
    self.profileImageView.tintColor = theme.secondaryColor

    self.proLabel.textColor = theme.primaryColor
    self.costLabel.textColor = theme.secondaryColor
    self.imageViews.forEach({ $0.tintColor = theme.linkColor })
    self.imageOverlayView.backgroundColor = theme.linkColor
    self.secondaryLabels.forEach({ $0.textColor = theme.primaryColor })
    self.completeAccountButton.tintColor = theme.linkColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
      ? UIUserInterfaceStyle.dark
      : UIUserInterfaceStyle.light
  }
}
