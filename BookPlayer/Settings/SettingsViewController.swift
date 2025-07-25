//
//  SettingsViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/29/17.
//  Copyright © 2017 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import DeviceKit
import IntentsUI
import MessageUI
import SafariServices
import Themeable
import UIKit
import SwiftUI

protocol IntentSelectionDelegate: AnyObject {
  func didSelectIntent(_ intent: INIntent)
}

// TODO: Replace with SwiftUI view when we drop support for iOS 14, we need the .badge modifier (iOS 15 required)
class SettingsViewController: UITableViewController, MVVMControllerProtocol, MFMailComposeViewControllerDelegate, Storyboarded {
  @IBOutlet weak var iCloudBackupsSwitch: UISwitch!
  @IBOutlet weak var crashReportsSwitch: UISwitch!
  @IBOutlet weak var allowCellularDataSwitch: UISwitch!
  @IBOutlet weak var lockOrientationSwitch: UISwitch!
  @IBOutlet weak var skanSwitch: UISwitch!
  @IBOutlet weak var themeLabel: UILabel!
  @IBOutlet weak var appIconLabel: UILabel!
  @IBOutlet weak var plusBannerView: PlusBannerView!

  private var disposeBag = Set<AnyCancellable>()
  var iconObserver: NSKeyValueObservation!
  var viewModel: SettingsViewModel!

  enum SettingsSection: Int {
    case plus = 0, appearance, playback, storage, data, siri, backups, jellyfin, hardcover, privacy, support
  }

  let playbackIndexPath = IndexPath(row: 0, section: SettingsSection.playback.rawValue)
  let autoplayIndexPath = IndexPath(row: 1, section: SettingsSection.playback.rawValue)
  let autolockIndexPath = IndexPath(row: 2, section: SettingsSection.playback.rawValue)
  let themesIndexPath = IndexPath(row: 0, section: SettingsSection.appearance.rawValue)
  let iconsIndexPath = IndexPath(row: 1, section: SettingsSection.appearance.rawValue)
  let storageIndexPath = IndexPath(row: 0, section: SettingsSection.storage.rawValue)
  let cloudDeletedIndexPath = IndexPath(row: 1, section: SettingsSection.storage.rawValue)
  let lastPlayedShortcutPath = IndexPath(row: 0, section: SettingsSection.siri.rawValue)
  let sleepTimerShortcutPath = IndexPath(row: 1, section: SettingsSection.siri.rawValue)
  let jellyfinManageConnectionPath = IndexPath(row: 0, section: SettingsSection.jellyfin.rawValue)
  let hardcoverPath = IndexPath(row: 0, section: SettingsSection.hardcover.rawValue)
  let tipJarPath = IndexPath(row: 0, section: SettingsSection.support.rawValue)

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

    bindObservers()
    bindDataItems()

    setupSwitchValues()

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

    self.appIconLabel.text = userDefaults?.string(forKey: Constants.UserDefaults.appIcon) ?? "Default"

    self.iconObserver = userDefaults?.observe(\.userSettingsAppIcon) { [weak self] _, _ in
      self?.appIconLabel.text = userDefaults?.string(forKey: Constants.UserDefaults.appIcon) ?? "Default"
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
    
    self.viewModel.$hasJellyfinConnection
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        self?.tableView.reloadData()
      }.store(in: &disposeBag)
  }

  func setupSwitchValues() {
    allowCellularDataSwitch.addTarget(self, action: #selector(self.allowCellularDataDidChange), for: .valueChanged)
    iCloudBackupsSwitch.addTarget(self, action: #selector(self.iCloudBackupsDidChange), for: .valueChanged)
    crashReportsSwitch.addTarget(self, action: #selector(crashReportsAccessDidChange), for: .valueChanged)
    skanSwitch.addTarget(self, action: #selector(skanPreferenceDidChange), for: .valueChanged)
    lockOrientationSwitch.addTarget(self, action: #selector(orientationLockDidChange), for: .valueChanged)

    // Set initial switch positions
    allowCellularDataSwitch.setOn(
      UserDefaults.standard.bool(forKey: Constants.UserDefaults.allowCellularData),
      animated: false
    )
    iCloudBackupsSwitch.setOn(
      UserDefaults.standard.bool(forKey: Constants.UserDefaults.iCloudBackupsEnabled),
      animated: false
    )
    crashReportsSwitch.setOn(
      UserDefaults.standard.bool(forKey: Constants.UserDefaults.crashReportsDisabled),
      animated: false
    )
    skanSwitch.setOn(
      UserDefaults.standard.bool(forKey: Constants.UserDefaults.skanAttributionDisabled),
      animated: false
    )
    lockOrientationSwitch.setOn(
      UserDefaults.standard.object(forKey: Constants.UserDefaults.orientationLock) != nil,
      animated: false
    )
  }

  @objc func donationMade() {
    self.tableView.reloadData()
  }

  @objc func allowCellularDataDidChange() {
    viewModel.toggleCellularDataUsage(allowCellularDataSwitch.isOn)
  }

  @objc func iCloudBackupsDidChange() {
    self.viewModel.toggleFileBackupsPreference(self.iCloudBackupsSwitch.isOn)
  }

  @objc func crashReportsAccessDidChange() {
    viewModel.toggleCrashReportsAccess(crashReportsSwitch.isOn)
  }

  @objc func skanPreferenceDidChange() {
    viewModel.toggleSKANPreference(skanSwitch.isOn)
  }

  @objc func orientationLockDidChange() {
    viewModel.toggleOrientationLockPreference(lockOrientationSwitch.isOn)
    setNeedsUpdateOfSupportedInterfaceOrientations()
  }

  func bindDataItems() {
    self.viewModel.observeEvents()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] event in
        switch event {
        case .showLoader(let flag):
          self?.showLoader(flag)
        case .showAlert(let content):
          self?.showAlert(content)
        }
      }
      .store(in: &disposeBag)
  }

  func showLoader(_ flag: Bool) {
    if flag {
      LoadingUtils.loadAndBlock(in: self)
    } else {
      LoadingUtils.stopLoading(in: self)
    }
  }

  override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    if indexPath == cloudDeletedIndexPath,
       !self.viewModel.hasMadeDonation() {
      return 0
    }

    if indexPath == lastPlayedShortcutPath {
      return 55
    }

    switch indexPath.section {
    case SettingsSection.plus.rawValue:
      if viewModel.hasMadeDonation() {
        return 0
      } else {
        return 152
      }
    case SettingsSection.data.rawValue:
      if viewModel.hasMadeDonation() {
        return super.tableView(tableView, heightForRowAt: indexPath)
      } else {
        return 0
      }
    case SettingsSection.jellyfin.rawValue:
      if viewModel.hasJellyfinConnection {
        return super.tableView(tableView, heightForRowAt: indexPath)
      } else {
        return 0
      }
    default:
      return super.tableView(tableView, heightForRowAt: indexPath)
    }
  }

  override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
    switch section {
    case SettingsSection.plus.rawValue:
      return CGFloat.leastNormalMagnitude
    case SettingsSection.data.rawValue:
      if viewModel.hasMadeDonation() {
        return super.tableView(tableView, heightForHeaderInSection: section)
      } else {
        return CGFloat.leastNormalMagnitude
      }
    case SettingsSection.jellyfin.rawValue:
      if viewModel.hasJellyfinConnection {
        return super.tableView(tableView, heightForHeaderInSection: section)
      } else {
        return CGFloat.leastNormalMagnitude
      }
    default:
      return super.tableView(tableView, heightForHeaderInSection: section)
    }
  }

  override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
    switch section {
    case SettingsSection.plus.rawValue:
      return CGFloat.leastNormalMagnitude
    case SettingsSection.data.rawValue:
      if viewModel.hasMadeDonation() {
        return super.tableView(tableView, heightForFooterInSection: section)
      } else {
        return CGFloat.leastNormalMagnitude
      }
    case SettingsSection.jellyfin.rawValue:
      if viewModel.hasJellyfinConnection {
        return super.tableView(tableView, heightForFooterInSection: section)
      } else {
        return CGFloat.leastNormalMagnitude
      }
    default:
      return super.tableView(tableView, heightForFooterInSection: section)
    }
  }

  override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath as IndexPath, animated: true)

    switch indexPath {
    case self.playbackIndexPath:
      self.viewModel.showPlayerControls()
    case self.autoplayIndexPath:
      self.viewModel.showAutoplay()
    case self.autolockIndexPath:
      self.viewModel.showAutolock()
    case self.themesIndexPath:
      self.viewModel.showThemes()
    case self.iconsIndexPath:
      self.viewModel.showIcons()
    case self.tipJarPath:
      self.viewModel.showTipJar()
    case self.lastPlayedShortcutPath:
      if #unavailable(iOS 16.4) {
        /// SiriKit shortcuts are deprecated
        self.showLastPlayedShortcut()
      }
    case self.sleepTimerShortcutPath:
      if #unavailable(iOS 16.4) { 
        /// SiriKit shortcuts are deprecated
        self.showSleepTimerShortcut()
      }
    case self.storageIndexPath:
      self.viewModel.showStorageManagement()
    case self.cloudDeletedIndexPath:
      self.viewModel.showCloudDeletedFiles()
    case self.jellyfinManageConnectionPath:
      self.viewModel.showJellyfinConnectionManagement()
    case self.hardcoverPath:
      self.viewModel.showHardcoverManagement()
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
    case .data:
      if viewModel.hasMadeDonation() {
        return "settings_datausage_title".localized
      } else {
        return nil
      }
    case .siri:
      return "settings_shortcuts_title".localized
    case .backups:
      return "settings_backup_title".localized
    case .jellyfin:
      if viewModel.hasJellyfinConnection {
        return "Jellyfin"
      } else {
        return nil
      }
    case .hardcover:
      return "Hardcover"
    case .privacy:
      return "settings_privacy_title".localized
    case .support:
      return "settings_support_title".localized
    default:
      return super.tableView(tableView, titleForHeaderInSection: section)
    }
  }

  override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    var tableViewCell = super.tableView(tableView, cellForRowAt: indexPath)

    if indexPath == autoplayIndexPath {
      /// Override title with capitalized string
      tableViewCell.textLabel?.text = "settings_autoplay_section_title".localized.localizedCapitalized
    }

    guard 
      #available(iOS 16.4, *)
    else {
      return tableViewCell
    }

    if indexPath == lastPlayedShortcutPath {
      tableViewCell = UITableViewCell()
      tableViewCell.contentConfiguration = UIHostingConfiguration {
        HStack {
          BPShortcutsLink()
          Spacer()
        }
        .padding(.leading)
      }
      .margins(.all, 0)
      tableViewCell.backgroundColor = .clear
    }

    return tableViewCell
  }

  override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    let totalCount = super.tableView(tableView, numberOfRowsInSection: section)

    guard let settingsSection = SettingsSection(rawValue: section) else {
      return totalCount
    }
    
    switch settingsSection {
    case .siri:
      if #available(iOS 16.4, *) {
        return totalCount - 1
      }
    case .jellyfin:
      if !viewModel.hasJellyfinConnection {
        return 0
      }
    default:
      break
    }

    return totalCount
  }

  override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
    guard let settingsSection = SettingsSection(rawValue: section) else {
      return super.tableView(tableView, titleForFooterInSection: section)
    }

    switch settingsSection {
    case .support:
      return "BookPlayer \(self.appVersion) - \(self.systemVersion)"
    case .privacy:
      return "settings_skan_attribution_description".localized
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
