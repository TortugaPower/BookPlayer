//
//  PlayerSettingsViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/19/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class PlayerSettingsViewController: UITableViewController {
    @IBOutlet weak var smartRewindSwitch: UISwitch!
    @IBOutlet weak var boostVolumeSwitch: UISwitch!
    @IBOutlet weak var globalSpeedSwitch: UISwitch!
    @IBOutlet weak var rewindIntervalLabel: UILabel!
    @IBOutlet weak var forwardIntervalLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpTheming()

        self.smartRewindSwitch.addTarget(self, action: #selector(self.rewindToggleDidChange), for: .valueChanged)
        self.boostVolumeSwitch.addTarget(self, action: #selector(self.boostVolumeToggleDidChange), for: .valueChanged)
        self.globalSpeedSwitch.addTarget(self, action: #selector(self.globalSpeedToggleDidChange), for: .valueChanged)

        // Set initial switch positions
        self.smartRewindSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.smartRewindEnabled.rawValue), animated: false)
        self.boostVolumeSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue), animated: false)
        self.globalSpeedSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue), animated: false)

        // Retrieve initial skip values from PlayerManager
        self.rewindIntervalLabel.text = self.formatDuration(PlayerManager.shared.rewindInterval)
        self.forwardIntervalLabel.text = self.formatDuration(PlayerManager.shared.forwardInterval)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let viewController = segue.destination as? SkipDurationViewController else {
            return
        }

        if segue.identifier == "AdjustRewindIntervalSegue" {
            viewController.title = "Rewind"
            viewController.selectedInterval = PlayerManager.shared.rewindInterval
            viewController.didSelectInterval = { selectedInterval in
                PlayerManager.shared.rewindInterval = selectedInterval

                self.rewindIntervalLabel.text = self.formatDuration(PlayerManager.shared.rewindInterval)
            }
        }

        if segue.identifier == "AdjustForwardIntervalSegue" {
            viewController.title = "Forward"
            viewController.selectedInterval = PlayerManager.shared.forwardInterval
            viewController.didSelectInterval = { selectedInterval in
                PlayerManager.shared.forwardInterval = selectedInterval

                self.forwardIntervalLabel.text = self.formatDuration(PlayerManager.shared.forwardInterval)
            }
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as? UITableViewHeaderFooterView
        header?.textLabel?.textColor = self.themeProvider.currentTheme.detailColor
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let footer = view as? UITableViewHeaderFooterView
        footer?.textLabel?.textColor = self.themeProvider.currentTheme.detailColor
    }

    @objc func rewindToggleDidChange() {
        UserDefaults.standard.set(self.smartRewindSwitch.isOn, forKey: Constants.UserDefaults.smartRewindEnabled.rawValue)
    }

    @objc func boostVolumeToggleDidChange() {
        UserDefaults.standard.set(self.boostVolumeSwitch.isOn, forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)
        PlayerManager.shared.boostVolume = self.boostVolumeSwitch.isOn
    }

    @objc func globalSpeedToggleDidChange() {
        UserDefaults.standard.set(self.globalSpeedSwitch.isOn, forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue)
    }
}

extension PlayerSettingsViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.tableView.backgroundColor = theme.settingsBackgroundColor
        self.tableView.separatorColor = theme.separatorColor
        self.tableView.reloadData()
    }
}
