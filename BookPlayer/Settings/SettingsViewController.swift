//
//  SettingsViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/29/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import DeviceKit
import MessageUI
import SafariServices
import UIKit

class SettingsViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet var autoplayLibrarySwitch: UISwitch!
    @IBOutlet var smartRewindSwitch: UISwitch!
    @IBOutlet var boostVolumeSwitch: UISwitch!
    @IBOutlet var globalSpeedSwitch: UISwitch!
    @IBOutlet var disableAutolockSwitch: UISwitch!
    @IBOutlet var rewindIntervalLabel: UILabel!
    @IBOutlet var forwardIntervalLabel: UILabel!

    let supportSection: Int = 5
    let githubLinkPath: IndexPath = IndexPath(row: 0, section: 6)
    let supportEmailPath: IndexPath = IndexPath(row: 1, section: 6)

    var version: String = "0.0.0"
    var build: String = "0"
    var supportEmail = "support@bookplayer.app"

    var appVersion: String {
        return "\(version)-\(build)"
    }

    var systemVersion: String {
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        autoplayLibrarySwitch.addTarget(self, action: #selector(autoplayToggleDidChange), for: .valueChanged)
        smartRewindSwitch.addTarget(self, action: #selector(rewindToggleDidChange), for: .valueChanged)
        boostVolumeSwitch.addTarget(self, action: #selector(boostVolumeToggleDidChange), for: .valueChanged)
        globalSpeedSwitch.addTarget(self, action: #selector(globalSpeedToggleDidChange), for: .valueChanged)
        disableAutolockSwitch.addTarget(self, action: #selector(disableAutolockDidChange), for: .valueChanged)

        // Set initial switch positions
        autoplayLibrarySwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue), animated: false)
        smartRewindSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.smartRewindEnabled.rawValue), animated: false)
        boostVolumeSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue), animated: false)
        globalSpeedSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue), animated: false)
        disableAutolockSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled.rawValue), animated: false)

        // Retrieve initial skip values from PlayerManager
        rewindIntervalLabel.text = formatDuration(PlayerManager.shared.rewindInterval)
        forwardIntervalLabel.text = formatDuration(PlayerManager.shared.forwardInterval)

        guard
            let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
        else {
            return
        }

        self.version = version
        self.build = build
    }

    override func prepare(for segue: UIStoryboardSegue, sender _: Any?) {
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

    @objc func autoplayToggleDidChange() {
        UserDefaults.standard.set(autoplayLibrarySwitch.isOn, forKey: Constants.UserDefaults.autoplayEnabled.rawValue)
    }

    @objc func rewindToggleDidChange() {
        UserDefaults.standard.set(smartRewindSwitch.isOn, forKey: Constants.UserDefaults.smartRewindEnabled.rawValue)
    }

    @objc func boostVolumeToggleDidChange() {
        UserDefaults.standard.set(boostVolumeSwitch.isOn, forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)
        PlayerManager.shared.boostVolume = boostVolumeSwitch.isOn
    }

    @objc func globalSpeedToggleDidChange() {
        UserDefaults.standard.set(globalSpeedSwitch.isOn, forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue)
    }

    @objc func disableAutolockDidChange() {
        UserDefaults.standard.set(disableAutolockSwitch.isOn, forKey: Constants.UserDefaults.autolockDisabled.rawValue)
    }

    @IBAction func done(_: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)

        switch indexPath {
        case supportEmailPath:
            sendSupportEmmail()
        case githubLinkPath:
            showProjectOnGitHub()
        default: break
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == supportSection {
            return "BookPlayer \(appVersion) on \(systemVersion)"
        }

        return super.tableView(tableView, titleForFooterInSection: section)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith _: MFMailComposeResult, error _: Error?) {
        controller.dismiss(animated: true)
    }

    func sendSupportEmmail() {
        let device = Device()

        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()

            mail.mailComposeDelegate = self
            mail.setToRecipients([self.supportEmail])
            mail.setSubject("I need help with BookPlayer \(version)-\(build)")
            mail.setMessageBody("<p>Hello BookPlayer Crew,<br>I have an issue concerning BookPlayer \(appVersion) on my \(device) running \(systemVersion)</p><p>When I try to…</p>", isHTML: true)

            present(mail, animated: true)
        } else {
            let debugInfo = "BookPlayer \(appVersion)\n\(device) with \(systemVersion)"

            let alert = UIAlertController(title: "Unable to compose email", message: "You need to set up an email account in your device settings to use this. \n\nPlease mail us at \(supportEmail)\n\n\(debugInfo)", preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Copy information to clipboard", style: .default, handler: { _ in
                UIPasteboard.general.string = "\(self.supportEmail)\n\(debugInfo)"
            }))

            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))

            present(alert, animated: true, completion: nil)
        }
    }

    func showProjectOnGitHub() {
        let url = URL(string: "https://github.com/GianniCarlo/Audiobook-Player")
        let safari = SFSafariViewController(url: url!)

        if #available(iOS 11.0, *) {
            safari.dismissButtonStyle = .close
        }

        present(safari, animated: true)
    }
}
