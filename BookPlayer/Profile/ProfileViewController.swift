//
//  ProfileViewController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 12/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import UIKit

class ProfileViewController: BaseViewController<ProfileCoordinator, ProfileViewModel>,
                             Storyboarded {
  override func viewDidLoad() {
    super.viewDidLoad()

    self.navigationItem.title = "Profile"

    self.navigationItem.rightBarButtonItem = UIBarButtonItem(
      image: UIImage(systemName: "gear"),
      style: .plain,
      target: self,
      action: #selector(didTapSettings)
    )
  }

  @objc func didTapSettings() {
    self.viewModel.showSettings()
  }
}
