//
//  SettingsViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 5/29/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {
    @IBOutlet weak var storageSizeLabel: UILabel!
    @IBOutlet weak var themeSwitch: UISwitch!
    @IBOutlet weak var smartRewindSwitch: UISwitch!
    @IBOutlet weak var boostVolumeSwitch: UISwitch!
    @IBOutlet weak var globalSpeedSwitch: UISwitch!
    @IBOutlet weak var autoplaySwitch: UISwitch!

    let defaults: UserDefaults = UserDefaults.standard

    override func viewDidLoad() {
        super.viewDidLoad()

        smartRewindSwitch.addTarget(self, action: #selector(self.rewindToggleDidChange), for: .valueChanged)
        boostVolumeSwitch.addTarget(self, action: #selector(self.boostVolumeToggleDidChange), for: .valueChanged)
        globalSpeedSwitch.addTarget(self, action: #selector(self.globalSpeedToggleDidChange), for: .valueChanged)
        autoplaySwitch.addTarget(self, action: #selector(self.autoplayToggleDidChange), for: .valueChanged)

        //Set initial switch positions
        smartRewindSwitch.setOn(defaults.bool(forKey: UserDefaultsConstants.smartRewindEnabled), animated: false)
        boostVolumeSwitch.setOn(defaults.bool(forKey: UserDefaultsConstants.boostVolumeEnabled), animated: false)
        globalSpeedSwitch.setOn(defaults.bool(forKey: UserDefaultsConstants.globalSpeedEnabled), animated: false)
        autoplaySwitch.setOn(defaults.bool(forKey: UserDefaultsConstants.autoplayEnabled), animated: false)
    }

    @objc func rewindToggleDidChange() {
        defaults.set(smartRewindSwitch.isOn, forKey: UserDefaultsConstants.smartRewindEnabled)
    }

    @objc func boostVolumeToggleDidChange() {
        defaults.set(boostVolumeSwitch.isOn, forKey: UserDefaultsConstants.boostVolumeEnabled)
    }

    @objc func globalSpeedToggleDidChange() {
        defaults.set(globalSpeedSwitch.isOn, forKey: UserDefaultsConstants.globalSpeedEnabled)
    }

    @objc func autoplayToggleDidChange() {
        defaults.set(autoplaySwitch.isOn, forKey: UserDefaultsConstants.autoplayEnabled)
    }

    @IBAction func done(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    //TODO: remove this once settings page is completed
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //hide all options except smart rewind
        switch section {
        case 0, 1:
            return 0
        default:
            return 4
        }
    }
}
