//
//  SettingsViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/29/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import DeviceKit
import IntentsUI
import MessageUI
import SafariServices
import Themeable
import UIKit

protocol IntentSelectionDelegate: AnyObject {
    func didSelectIntent(_ intent: INIntent)
}

class SettingsViewController: BaseTableViewController<SettingsCoordinator, SettingsViewModel>,
                              MFMailComposeViewControllerDelegate,
                              Storyboarded {
  @IBOutlet weak var autoplayLibrarySwitch: UISwitch!
  @IBOutlet weak var autoplayRestartSwitch: UISwitch!
  @IBOutlet weak var disableAutolockSwitch: UISwitch!
  @IBOutlet weak var autolockDisabledOnlyWhenPoweredSwitch: UISwitch!
  @IBOutlet weak var iCloudBackupsSwitch: UISwitch!
  @IBOutlet weak var autolockDisabledOnlyWhenPoweredLabel: UILabel!
  @IBOutlet weak var themeLabel: UILabel!
  @IBOutlet weak var appIconLabel: UILabel!
  @IBOutlet weak var plusBannerView: PlusBannerView!

  private var disposeBag = Set<AnyCancellable>()
  var iconObserver: NSKeyValueObservation!

  enum SettingsSection: Int {
    case plus = 0, appearance, playback, storage, autoplay, autolock, siri, backups, support, credits
  }

  let creditsIndexPath = IndexPath(row: 0, section: SettingsSection.credits.rawValue)
  let playbackIndexPath = IndexPath(row: 0, section: SettingsSection.playback.rawValue)
  let themesIndexPath = IndexPath(row: 0, section: SettingsSection.appearance.rawValue)
  let iconsIndexPath = IndexPath(row: 1, section: SettingsSection.appearance.rawValue)
  let storageIndexPath = IndexPath(row: 0, section: SettingsSection.storage.rawValue)
  let lastPlayedShortcutPath = IndexPath(row: 0, section: SettingsSection.siri.rawValue)
  let sleepTimerShortcutPath = IndexPath(row: 1, section: SettingsSection.siri.rawValue)
  let githubLinkPath = IndexPath(row: 0, section: SettingsSection.support.rawValue)
  let supportEmailPath = IndexPath(row: 1, section: SettingsSection.support.rawValue)
  let tipJarPath = IndexPath(row: 2, section: SettingsSection.support.rawValue)

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

    self.navigationItem.title = "settings_title".localized

    setUpTheming()

    self.bindObservers()

    self.setupSwitchValues()

    guard
      let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String,
      let build = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
    else {
      return
    }

    self.version = version
    self.build = build

    self.tableView.contentInset.bottom = 88
  }

  func bindObservers() {
    let userDefaults = UserDefaults(suiteName: Constants.ApplicationGroupIdentifier)

    self.appIconLabel.text = userDefaults?.string(forKey: Constants.UserDefaults.appIcon.rawValue) ?? "Default"

    self.iconObserver = userDefaults?.observe(\.userSettingsAppIcon) { [weak self] _, _ in
        self?.appIconLabel.text = userDefaults?.string(forKey: Constants.UserDefaults.appIcon.rawValue) ?? "Default"
    }

    if self.viewModel.hasMadeDonation() {
      self.donationMade()
    } else {
      self.viewModel.$account
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
        self?.donationMade()
      }
      .store(in: &disposeBag)
    }

    self.plusBannerView.showPlus = { [weak self] in
      self?.viewModel.showPro()
    }
  }

  func setupSwitchValues() {
    self.autoplayLibrarySwitch.addTarget(self, action: #selector(self.autoplayToggleDidChange), for: .valueChanged)
    self.autoplayRestartSwitch.addTarget(self, action: #selector(self.autoplayRestartToggleDidChange), for: .valueChanged)
    self.disableAutolockSwitch.addTarget(self, action: #selector(self.disableAutolockDidChange), for: .valueChanged)
    self.autolockDisabledOnlyWhenPoweredSwitch.addTarget(self, action: #selector(self.autolockOnlyWhenPoweredDidChange), for: .valueChanged)
    self.iCloudBackupsSwitch.addTarget(self, action: #selector(self.iCloudBackupsDidChange), for: .valueChanged)

    // Set initial switch positions
    self.iCloudBackupsSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.iCloudBackupsEnabled.rawValue), animated: false)
    let isAutoplayEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayEnabled.rawValue)
    self.autoplayLibrarySwitch.setOn(isAutoplayEnabled, animated: false)
    autoplayRestartSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autoplayRestartEnabled.rawValue), animated: false)
    if !isAutoplayEnabled {
      autoplayRestartSwitch.isEnabled = false
    }
    self.disableAutolockSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled.rawValue), animated: false)
    self.autolockDisabledOnlyWhenPoweredSwitch.setOn(UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabledOnlyWhenPowered.rawValue), animated: false)
    self.autolockDisabledOnlyWhenPoweredSwitch.isEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled.rawValue)
    self.autolockDisabledOnlyWhenPoweredLabel.isEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.autolockDisabled.rawValue)
  }

    @objc func donationMade() {
        self.tableView.reloadData()
    }

    @objc func autoplayToggleDidChange() {
        UserDefaults.standard.set(self.autoplayLibrarySwitch.isOn, forKey: Constants.UserDefaults.autoplayEnabled.rawValue)
      self.autoplayRestartSwitch.isEnabled = autoplayLibrarySwitch.isOn
    }

    @objc func autoplayRestartToggleDidChange() {
      UserDefaults.standard.set(self.autoplayRestartSwitch.isOn, forKey: Constants.UserDefaults.autoplayRestartEnabled.rawValue)
    }

    @objc func disableAutolockDidChange() {
        UserDefaults.standard.set(self.disableAutolockSwitch.isOn, forKey: Constants.UserDefaults.autolockDisabled.rawValue)
        self.autolockDisabledOnlyWhenPoweredSwitch.isEnabled = self.disableAutolockSwitch.isOn
        self.autolockDisabledOnlyWhenPoweredLabel.isEnabled = self.disableAutolockSwitch.isOn
    }

    @objc func autolockOnlyWhenPoweredDidChange() {
        UserDefaults.standard.set(self.autolockDisabledOnlyWhenPoweredSwitch.isOn, forKey: Constants.UserDefaults.autolockDisabledOnlyWhenPowered.rawValue)
    }

  @objc func iCloudBackupsDidChange() {
    self.viewModel.toggleFileBackupsPreference(self.iCloudBackupsSwitch.isOn)
  }

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    guard indexPath.section == 0 else {
      return super.tableView(tableView, heightForRowAt: indexPath)
    }

    guard !self.viewModel.hasMadeDonation() else { return 0 }

    return 152
  }

  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    guard
      section == 0
    else {
      return super.tableView(tableView, heightForHeaderInSection: section)
    }

    return CGFloat.leastNormalMagnitude
  }

  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    guard
      section == 0
    else {
      return super.tableView(tableView, heightForFooterInSection: section)
    }

    return CGFloat.leastNormalMagnitude
  }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath as IndexPath, animated: true)

        switch indexPath {
        case self.creditsIndexPath:
          self.viewModel.showCredits()
        case self.playbackIndexPath:
          self.viewModel.showPlayerControls()
        case self.themesIndexPath:
          self.viewModel.showThemes()
        case self.iconsIndexPath:
          self.viewModel.showIcons()
        case self.tipJarPath:
          self.viewModel.showTipJar()
        case self.supportEmailPath:
          self.sendSupportEmail()
        case self.githubLinkPath:
          self.showProjectOnGitHub()
        case self.lastPlayedShortcutPath:
          self.showLastPlayedShortcut()
        case self.sleepTimerShortcutPath:
          self.showSleepTimerShortcut()
        case self.storageIndexPath:
          self.viewModel.showStorageManagement()
        default: break
        }
    }

  override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    guard let settingsSection = SettingsSection(rawValue: section) else {
      return super.tableView(tableView, titleForFooterInSection: section)
    }

    switch settingsSection {
    case .appearance:
      return "settings_appearance_title".localized
    case .playback:
      return "settings_playback_title".localized
    case .storage:
      return "settings_storage_title".localized
    case .siri:
      return "settings_siri_title".localized
    case .backups:
      return "settings_backup_title".localized
    case .support:
      return "settings_support_title".localized
    default:
      return super.tableView(tableView, titleForHeaderInSection: section)
    }
  }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        guard let settingsSection = SettingsSection(rawValue: section) else {
            return super.tableView(tableView, titleForFooterInSection: section)
        }

        switch settingsSection {
        case .autoplay:
            return "settings_autoplay_description".localized
        case .autolock:
            return "settings_autolock_description".localized
        case .support:
            return "BookPlayer \(self.appVersion) - \(self.systemVersion)"
        default:
            return super.tableView(tableView, titleForFooterInSection: section)
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

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }

    func showLastPlayedShortcut() {
        let intent = INPlayMediaIntent()

        guard let shortcut = INShortcut(intent: intent) else { return }

        let vc = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        vc.delegate = self

        self.present(vc, animated: true, completion: nil)
    }

    func showSleepTimerShortcut() {
      let intent = SleepTimerIntent()
      intent.option = .unknown
      let shortcut = INShortcut(intent: intent)!

      let vc = INUIAddVoiceShortcutViewController(shortcut: shortcut)
      vc.delegate = self

      self.present(vc, animated: true, completion: nil)
    }

    @IBAction func sendSupportEmail() {
        let device = Device.current

        if MFMailComposeViewController.canSendMail() {
            let mail = MFMailComposeViewController()

            mail.mailComposeDelegate = self
            mail.setToRecipients([self.supportEmail])
            mail.setSubject("I need help with BookPlayer \(self.version)-\(self.build)")
            mail.setMessageBody("<p>Hello BookPlayer Crew,<br>I have an issue concerning BookPlayer \(self.appVersion) on my \(device) running \(self.systemVersion)</p><p>When I try to…</p>", isHTML: true)

            self.present(mail, animated: true)
        } else {
            let debugInfo = "BookPlayer \(self.appVersion)\n\(device) - \(self.systemVersion)"
            let message = "settings_support_compose_description".localized

            let alert = UIAlertController(title: "settings_support_compose_title".localized, message: "\(message) \(self.supportEmail)\n\n\(debugInfo)", preferredStyle: .alert)

            alert.addAction(UIAlertAction(title: "settings_support_compose_copy".localized, style: .default, handler: { [weak self] _ in
              guard let self = self else { return }
              UIPasteboard.general.string = "\(self.supportEmail)\n\(debugInfo)"
            }))

            alert.addAction(UIAlertAction(title: "ok_button".localized, style: .cancel, handler: nil))

            self.present(alert, animated: true, completion: nil)
        }
    }

    func showProjectOnGitHub() {
        let url = URL(string: "https://github.com/TortugaPower/BookPlayer")
        let safari = SFSafariViewController(url: url!)
        safari.dismissButtonStyle = .close

        self.present(safari, animated: true)
    }
}

extension SettingsViewController: INUIAddVoiceShortcutViewControllerDelegate {
    func addVoiceShortcutViewControllerDidCancel(_ controller: INUIAddVoiceShortcutViewController) {
        self.dismiss(animated: true, completion: nil)
    }

    func addVoiceShortcutViewController(_ controller: INUIAddVoiceShortcutViewController, didFinishWith voiceShortcut: INVoiceShortcut?, error: Error?) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension SettingsViewController: IntentSelectionDelegate {
    func didSelectIntent(_ intent: INIntent) {
        let shortcut = INShortcut(intent: intent)!
        let vc = INUIAddVoiceShortcutViewController(shortcut: shortcut)
        vc.delegate = self
        self.present(vc, animated: true, completion: nil)
    }
}

extension SettingsViewController: Themeable {
    func applyTheme(_ theme: SimpleTheme) {
      self.themeLabel.text = theme.title
      self.tableView.backgroundColor = theme.systemGroupedBackgroundColor
      self.tableView.separatorColor = theme.systemGroupedBackgroundColor
      self.tableView.reloadData()

      self.overrideUserInterfaceStyle = theme.useDarkVariant
        ? UIUserInterfaceStyle.dark
        : UIUserInterfaceStyle.light
    }
}
