//
//  AccountViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 8/4/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
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
  @IBOutlet weak var signoutImageView: UIImageView!

  private var disposeBag = Set<AnyCancellable>()

  enum AccountSection: Int {
    case info = 0, proEnabled, pro, logout, delete
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    setUpTheming()

    self.navigationItem.title = "Account"

    self.tableView.tableFooterView = UIView()

    setupViews()
    bindObservers()
  }

  func setupViews() {
    self.completeAccountButton.layer.masksToBounds = true
    self.completeAccountButton.layer.cornerRadius = 5
    self.imageOverlayView.layer.masksToBounds = true
    self.imageOverlayView.layer.cornerRadius = 10
    self.containerProfileImageView.layer.masksToBounds = true
    self.containerProfileImageView.layer.cornerRadius = self.containerProfileImageView.frame.width / 2
    self.containerProfileCardView.layer.masksToBounds = true
    self.containerProfileCardView.layer.cornerRadius = 10

    if #available(iOS 15, *) {
      self.signoutImageView.image = UIImage(systemName: "rectangle.portrait.and.arrow.right")
    } else {
      self.signoutImageView.image = UIImage(systemName: "square.and.arrow.up")
      self.signoutImageView.transform = self.signoutImageView.transform.rotated(by: .pi / 2)
    }
  }

  func bindObservers() {
    self.viewModel.$account
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.tableView.reloadData()
    }
    .store(in: &disposeBag)
  }

  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    return CGFloat.leastNormalMagnitude
  }

  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    switch section {
    case AccountSection.pro.rawValue:
      if self.viewModel.hasSubscription() {
        return CGFloat.leastNormalMagnitude
      } else {
        return super.tableView(tableView, heightForHeaderInSection: section)
      }
    case AccountSection.proEnabled.rawValue:
      if self.viewModel.hasSubscription() {
        return super.tableView(tableView, heightForHeaderInSection: section)
      } else {
        return CGFloat.leastNormalMagnitude
      }
    default:
      return super.tableView(tableView, heightForHeaderInSection: section)
    }
  }

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    switch indexPath.section {
    case AccountSection.pro.rawValue:
      if self.viewModel.hasSubscription() {
        return CGFloat.leastNormalMagnitude
      } else {
        return super.tableView(tableView, heightForRowAt: indexPath)
      }
    case AccountSection.proEnabled.rawValue:
      if self.viewModel.hasSubscription() {
        return super.tableView(tableView, heightForRowAt: indexPath)
      } else {
        return CGFloat.leastNormalMagnitude
      }
    default:
      return super.tableView(tableView, heightForRowAt: indexPath)
    }
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath as IndexPath, animated: true)

    switch indexPath.section {
    case AccountSection.proEnabled.rawValue:
      self.viewModel.showManageSubscription()
    case AccountSection.logout.rawValue:
      self.viewModel.handleLogout()
    case AccountSection.delete.rawValue:
      self.viewModel.showDeleteAlert()
    default:
      break
    }
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
