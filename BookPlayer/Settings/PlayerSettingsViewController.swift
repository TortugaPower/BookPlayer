//
//  PlayerSettingsViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/19/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class PlayerSettingsViewController: UITableViewController, TelemetryProtocol {
    @IBOutlet weak var smartRewindSwitch: UISwitch!
    @IBOutlet weak var boostVolumeSwitch: UISwitch!
    @IBOutlet weak var globalSpeedSwitch: UISwitch!
    @IBOutlet weak var rewindIntervalLabel: UILabel!
    @IBOutlet weak var forwardIntervalLabel: UILabel!

    enum SettingsSection: Int {
        case intervals = 0, rewind, volume, speed
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setUpTheming()

        self.navigationItem.title = "settings_controls_title".localized
        self.smartRewindSwitch.addTarget(self, action: #selector(self.rewindToggleDidChange), for: .valueChanged)
        self.boostVolumeSwitch.addTarget(self, action: #selector(self.boostVolumeToggleDidChange), for: .valueChanged)
        self.globalSpeedSwitch.addTarget(self, action: #selector(self.globalSpeedToggleDidChange), for: .valueChanged)

        // Set initial switch positions
        self.smartRewindSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.smartRewindEnabled.rawValue), animated: false)
        self.boostVolumeSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue), animated: false)
        self.globalSpeedSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue), animated: false)

        // Retrieve initial skip values from PlayerManager
        self.rewindIntervalLabel.text = TimeParser.formatDuration(PlayerManager.rewindInterval)
        self.forwardIntervalLabel.text = TimeParser.formatDuration(PlayerManager.forwardInterval)
        self.sendSignal(.playerControlsScreen, with: nil)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard let viewController = segue.destination as? SkipDurationViewController else {
            return
        }

        if segue.identifier == "AdjustRewindIntervalSegue" {
            self.sendSignal(.rewindIntervalsScreen, with: nil)
            viewController.title = "settings_skip_rewind_title".localized
            viewController.selectedInterval = PlayerManager.rewindInterval
            viewController.didSelectInterval = { selectedInterval in
                PlayerManager.rewindInterval = selectedInterval

                self.rewindIntervalLabel.text = TimeParser.formatDuration(PlayerManager.rewindInterval)
            }
        }

        if segue.identifier == "AdjustForwardIntervalSegue" {
            self.sendSignal(.forwardIntervalsScreen, with: nil)
            viewController.title = "settings_skip_forward_title".localized
            viewController.selectedInterval = PlayerManager.forwardInterval
            viewController.didSelectInterval = { selectedInterval in
                PlayerManager.forwardInterval = selectedInterval

                self.forwardIntervalLabel.text = TimeParser.formatDuration(PlayerManager.forwardInterval)
            }
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as? UITableViewHeaderFooterView
        header?.textLabel?.textColor = self.themeProvider.currentTheme.secondaryColor
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let footer = view as? UITableViewHeaderFooterView
        footer?.textLabel?.textColor = self.themeProvider.currentTheme.secondaryColor
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == SettingsSection.intervals.rawValue {
            return "settings_skip_title".localized
        }

        return super.tableView(tableView, titleForHeaderInSection: section)
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let settingsSection = SettingsSection(rawValue: section) else {
            return super.tableView(tableView, titleForFooterInSection: section)
        }

        switch settingsSection {
        case .intervals:
            return "settings_skip_description".localized
        case .rewind:
            return "settings_smartrewind_description".localized
        case .volume:
            return "settings_boostvolume_description".localized
        case .speed:
            return "settings_globalspeed_description".localized
        }
    }

    @objc func rewindToggleDidChange() {
        UserDefaults.standard.set(self.smartRewindSwitch.isOn, forKey: Constants.UserDefaults.smartRewindEnabled.rawValue)
    }

    @objc func boostVolumeToggleDidChange() {
      UserDefaults.standard.set(self.boostVolumeSwitch.isOn, forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)

      guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
            let mainCoordinator = appDelegate.coordinator.getMainCoordinator() else { return }

      mainCoordinator.playerManager.boostVolume = self.boostVolumeSwitch.isOn
    }

    @objc func globalSpeedToggleDidChange() {
        UserDefaults.standard.set(self.globalSpeedSwitch.isOn, forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue)
    }
}

extension PlayerSettingsViewController: Themeable {
    func applyTheme(_ theme: SimpleTheme) {
        self.tableView.backgroundColor = theme.systemGroupedBackgroundColor
        self.tableView.separatorColor = theme.separatorColor
        self.tableView.reloadData()
    }
}
