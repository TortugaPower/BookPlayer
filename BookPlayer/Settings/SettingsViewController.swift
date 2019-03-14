//
//  SettingsViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/29/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import DeviceKit
import IntentsUI
import MessageUI
import SafariServices
import Themeable
import UIKit

class SettingsViewController: UITableViewController, MFMailComposeViewControllerDelegate {
    @IBOutlet weak var autoplayLibrarySwitch: UISwitch!
    @IBOutlet weak var disableAutolockSwitch: UISwitch!
    @IBOutlet weak var themeLabel: UILabel!
    @IBOutlet weak var appIconLabel: UILabel!

    var iconObserver: NSKeyValueObservation!

    let siriShortcutPath = IndexPath(row: 0, section: 5)
    let supportSection: Int = 6
    let githubLinkPath = IndexPath(row: 0, section: 6)
    let supportEmailPath = IndexPath(row: 1, section: 6)

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

        setUpTheming()

        self.appIconLabel.text = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue) ?? "Default"

        self.iconObserver = UserDefaults.standard.observe(\.userSettingsAppIcon) { _, _ in
            self.appIconLabel.text = UserDefaults.standard.string(forKey: Constants.UserDefaults.appIcon.rawValue) ?? "Default"
        }
        if UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue) {
            self.donationMade()
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(self.donationMade), name: .donationMade, object: nil)
        }

        self.autoplayLibrarySwitch.addTarget(self, action: #selector(self.autoplayToggleDidChange), for: .valueChanged)
        self.disableAutolockSwitch.addTarget(self, action: #selector(self.disableAutolockDidChange), for: .valueChanged)

        // Set initial switch positions
        self.autoplayLibrarySwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue), animated: false)
        self.disableAutolockSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled.rawValue), animated: false)

        guard
            let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
        else {
            return
        }

        self.version = version
        self.build = build
    }

    @objc func donationMade() {
        self.tableView.reloadData()
    }

    @objc func autoplayToggleDidChange() {
        UserDefaults.standard.set(self.autoplayLibrarySwitch.isOn, forKey: Constants.UserDefaults.autoplayEnabled.rawValue)
    }

    @objc func disableAutolockDidChange() {
        UserDefaults.standard.set(self.disableAutolockSwitch.isOn, forKey: Constants.UserDefaults.autolockDisabled.rawValue)
    }

    @IBAction func done(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.section == 0 else {
            return super.tableView(tableView, heightForRowAt: indexPath)
        }

        guard !UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue) else { return 0 }

        return 102
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        guard section == 0, UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue) else {
            return super.tableView(tableView, heightForHeaderInSection: section)
        }

        return CGFloat.leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        guard section == 0, UserDefaults.standard.bool(forKey: Constants.UserDefaults.donationMade.rawValue) else {
            return super.tableView(tableView, heightForFooterInSection: section)
        }

        return CGFloat.leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)

        switch indexPath {
        case self.supportEmailPath:
            self.sendSupportEmail()
        case self.githubLinkPath:
            self.showProjectOnGitHub()
        case self.siriShortcutPath:
            self.showSiriShortcut()
        default: break
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == self.supportSection {
            return "BookPlayer \(self.appVersion) on \(self.systemVersion)"
        }

        return super.tableView(tableView, titleForFooterInSection: section)
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let header = view as? UITableViewHeaderFooterView
        header?.textLabel?.textColor = self.themeProvider.currentTheme.detailColor
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let footer = view as? UITableViewHeaderFooterView
        footer?.textLabel?.textColor = self.themeProvider.currentTheme.detailColor
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

    func showSiriShortcut() {
        if #available(iOS 12.0, *) {
            let shortcut = INShortcut(userActivity: UserActivityManager.shared.currentActivity)
            let vc = INUIAddVoiceShortcutViewController(shortcut: shortcut)
            vc.delegate = self
            self.present(vc, animated: true, completion: nil)
        } else {
            self.showAlert(nil, message: "Siri Shortcuts are available on iOS 12 and above")
        }
    }

    @IBAction func sendSupportEmail() {
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

extension SettingsViewController: INUIAddVoiceShortcutViewControllerDelegate {
    @available(iOS 12.0, *)
    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        self.dismiss(animated: true, completion: nil)
    }

    @available(iOS 12.0, *)
    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension SettingsViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.themeLabel.text = theme.title
        self.tableView.backgroundColor = theme.settingsBackgroundColor
        self.tableView.separatorColor = theme.settingsBackgroundColor
        self.tableView.reloadData()
    }
}
