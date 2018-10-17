//
//  SettingsViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/29/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import UIKit
import MessageUI
import SafariServices
import DeviceKit

class SettingsViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var autoplayLibrarySwitch: UISwitch!
    @IBOutlet weak var smartRewindSwitch: UISwitch!
    @IBOutlet weak var boostVolumeSwitch: UISwitch!
    @IBOutlet weak var globalSpeedSwitch: UISwitch!
    @IBOutlet weak var disableAutolockSwitch: UISwitch!
    @IBOutlet weak var rewindIntervalLabel: UILabel!
    @IBOutlet weak var forwardIntervalLabel: UILabel!

    let supportSection: Int = 5
    let githubLinkPath: IndexPath = IndexPath(row: 0, section: 6)
    let supportEmailPath: IndexPath = IndexPath(row: 1, section: 6)

    var version: String = "0.0.0"
    var build: String = "0"
    var supportEmail = "support@bookplayer.app"

    var appVersion: String {
        return "\(self.version)-\(self.build)"
    }

    var systemVersion: String {
        return "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.autoplayLibrarySwitch.addTarget(self, action: #selector(self.autoplayToggleDidChange), for: .valueChanged)
        self.smartRewindSwitch.addTarget(self, action: #selector(self.rewindToggleDidChange), for: .valueChanged)
        self.boostVolumeSwitch.addTarget(self, action: #selector(self.boostVolumeToggleDidChange), for: .valueChanged)
        self.globalSpeedSwitch.addTarget(self, action: #selector(self.globalSpeedToggleDidChange), for: .valueChanged)
        self.disableAutolockSwitch.addTarget(self, action: #selector(self.disableAutolockDidChange), for: .valueChanged)

        // Set initial switch positions
        self.autoplayLibrarySwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue), animated: false)
        self.smartRewindSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.smartRewindEnabled.rawValue), animated: false)
        self.boostVolumeSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue), animated: false)
        self.globalSpeedSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue), animated: false)
        self.disableAutolockSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled.rawValue), animated: false)

        // Retrieve initial skip values from PlayerManager
        self.rewindIntervalLabel.text = self.formatDuration(PlayerManager.shared.rewindInterval)
        self.forwardIntervalLabel.text = self.formatDuration(PlayerManager.shared.forwardInterval)

        guard
            let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
        else {
            return
        }

        self.version = version
        self.build = build
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

    @objc func autoplayToggleDidChange() {
        UserDefaults.standard.set(self.autoplayLibrarySwitch.isOn, forKey: Constants.UserDefaults.autoplayEnabled.rawValue)
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

    @objc func disableAutolockDidChange() {
        UserDefaults.standard.set(self.disableAutolockSwitch.isOn, forKey: Constants.UserDefaults.autolockDisabled.rawValue)
    }

    @IBAction func done(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)

        switch indexPath {
            case self.supportEmailPath:
                self.sendSupportEmmail()
            case self.githubLinkPath:
                self.showProjectOnGitHub()
            default: break
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == self.supportSection {
            return "BookPlayer \(self.appVersion) on \(self.systemVersion)"
        }

        return super.tableView(tableView, titleForFooterInSection: section)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

    func sendSupportEmmail() {
        let device = Device()

        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()

            mail.mailComposeDelegate = self
            mail.setToRecipients([self.supportEmail])
            mail.setSubject("I need help with BookPlayer \(self.version)-\(self.build)")
            mail.setMessageBody("<p>Hello BookPlayer Crew,<br>I have an issue concerning BookPlayer \(self.appVersion) on my \(device) running \(self.systemVersion)</p><p>When I try to…</p>", isHTML: true)

            self.present(mail, animated: true)
        } else {
            let debugInfo = "BookPlayer \(self.appVersion)\n\(device) with \(self.systemVersion)"

            let alert = UIAlertController(title: "Unable to compose email", message: "You need to set up an email account in your device settings to use this. \n\nPlease mail us at \(self.supportEmail)\n\n\(debugInfo)", preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "Copy information to clipboard", style: .default, handler: { _ in
                UIPasteboard.general.string = "\(self.supportEmail)\n\(debugInfo)"
            }))

            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))

            self.present(alert, animated: true, completion: nil)
        }
    }

    func showProjectOnGitHub() {
        let url = URL(string: "https://github.com/GianniCarlo/Audiobook-Player")
        let safari = SFSafariViewController(url: url!)

        if #available(iOS 11.0, *) {
            safari.dismissButtonStyle = .close
        }

        self.present(safari, animated: true)
    }
}
