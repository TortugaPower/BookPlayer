//
//  PlayerControlsViewController.swift
//  BookPlayer
//
//  Created by Pavel Kyzmin on 03.01.2022.
//  Copyright © 2021 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

class PlayerControlsViewController: UIViewController, Storyboarded {
  var viewModel: PlayerControlsViewModel!
  @IBOutlet weak var mainContainterStackView: UIStackView!
  @IBOutlet weak var playbackContainerStackView: UIStackView!
  @IBOutlet weak var boostContainerStackView: UIStackView!

  @IBOutlet weak var separatorView: UIView!
  @IBOutlet weak var playbackLabel: UILabel!
  @IBOutlet weak var currentSpeedSlider: AccessibleSliderView!
  @IBOutlet weak var currentSpeedLabel: UILabel!
  @IBOutlet weak var speedFirstQuickActionButton: UIButton!
  @IBOutlet weak var speedSecondQuickActionButton: UIButton!
  @IBOutlet weak var speedThirdQuickActionButton: UIButton!
  @IBOutlet weak var decrementSpeedButton: UIButton!
  @IBOutlet weak var incrementSpeedButton: UIButton!

  @IBOutlet weak var boostLabel: UILabel!
  @IBOutlet weak var boostWarningLabel: UILabel!
  @IBOutlet weak var boostSwitchControl: UISwitch!
  @IBOutlet weak var moreButton: UIButton!

  private var boostVolumeObserver: NSKeyValueObservation?

  private var disposeBag = Set<AnyCancellable>()

  override func viewDidLoad() {
    super.viewDidLoad()

    self.setupUI()
    self.setupAccessibility()
    self.bindBoostVolumeObservers()
    self.bindSpeedObservers()

    self.setUpTheming()
  }

  func setupUI() {
    self.navigationItem.title = "settings_controls_title".localized
    self.playbackLabel.text = "player_speed_title".localized
    self.boostLabel.text = "settings_boostvolume_title".localized
    self.boostWarningLabel.text = "settings_boostvolume_description".localized
    self.moreButton.setTitle("more_title".localized, for: .normal)

    self.speedFirstQuickActionButton.layer.masksToBounds = true
    self.speedFirstQuickActionButton.layer.cornerRadius = 5
    self.speedSecondQuickActionButton.layer.masksToBounds = true
    self.speedSecondQuickActionButton.layer.cornerRadius = 5
    self.speedThirdQuickActionButton.layer.masksToBounds = true
    self.speedThirdQuickActionButton.layer.cornerRadius = 5

    self.currentSpeedSlider.minimumValue = self.viewModel.getMinimumSpeedValue()
    self.currentSpeedSlider.maximumValue = self.viewModel.getMaximumSpeedValue()
    self.currentSpeedSlider.value = self.viewModel.getCurrentSpeed()

    if let titleDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline).withSymbolicTraits(.traitBold) {
      self.speedFirstQuickActionButton.titleLabel?.font = UIFont(descriptor: titleDescriptor, size: 0.0)
      self.speedFirstQuickActionButton.titleLabel?.adjustsFontForContentSizeCategory = true
      self.speedSecondQuickActionButton.titleLabel?.font = UIFont(descriptor: titleDescriptor, size: 0.0)
      self.speedSecondQuickActionButton.titleLabel?.adjustsFontForContentSizeCategory = true
      self.speedThirdQuickActionButton.titleLabel?.font = UIFont(descriptor: titleDescriptor, size: 0.0)
      self.speedThirdQuickActionButton.titleLabel?.adjustsFontForContentSizeCategory = true

      self.playbackLabel.font = UIFont(descriptor: titleDescriptor, size: 0.0)
      self.playbackLabel.adjustsFontForContentSizeCategory = true
      self.boostLabel.font = UIFont(descriptor: titleDescriptor, size: 0.0)
      self.boostLabel.adjustsFontForContentSizeCategory = true
    }

    self.boostSwitchControl.setOn(self.viewModel.getBoostVolumeFlag(), animated: false)
  }

  func setupAccessibility() {
    self.boostLabel.accessibilityHint = "settings_boostvolume_description".localized
    self.decrementSpeedButton.accessibilityLabel = "➖"
    self.currentSpeedSlider.accessibilityValue = "\(self.viewModel.getCurrentSpeed())"
    self.incrementSpeedButton.accessibilityLabel = "➕"
    self.boostWarningLabel.isAccessibilityElement = false
    self.currentSpeedLabel.isAccessibilityElement = false

    self.mainContainterStackView.accessibilityElements = [
      self.playbackLabel!,
      self.decrementSpeedButton!,
      self.currentSpeedSlider!,
      self.incrementSpeedButton!,
      self.boostLabel!,
      self.boostSwitchControl!,
      self.moreButton!
    ]
  }

  func bindBoostVolumeObservers() {
    self.boostSwitchControl.publisher(for: .valueChanged)
      .sink { [weak self] control in
        guard let switchControl = control as? UISwitch else { return }

        self?.viewModel.handleBoostVolumeToggle(flag: switchControl.isOn)
      }
      .store(in: &disposeBag)

    boostVolumeObserver = UserDefaults.standard.observe(
      \.userSettingsBoostVolume,
       options: [.new]
    ) { [weak self] _, change in
      guard let newValue = change.newValue else { return }
      self?.boostSwitchControl.setOn(newValue, animated: false)
    }
  }

  func bindSpeedObservers() {
    self.currentSpeedSlider.publisher(for: .valueChanged)
      .sink { [weak self] control in
        guard let self = self,
              let slider = control as? UISlider else { return }

        let roundedSpeedValue = self.viewModel.roundSpeedValue(slider.value)
        self.currentSpeedSlider.accessibilityValue = "\(roundedSpeedValue)"
        self.setSliderSpeed(roundedSpeedValue)
      }
      .store(in: &disposeBag)

    self.viewModel.currentSpeedPublisher()
      .removeDuplicates()
      .sink { [weak self] speed in
        guard let self = self else { return }

        let formattedSpeed = self.formatSpeed(speed)
        self.currentSpeedLabel.text = formattedSpeed
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
      }
      .store(in: &disposeBag)

    self.speedFirstQuickActionButton.publisher(for: .touchUpInside)
      .sink { [weak self] _ in
        self?.setSliderSpeed(1)
      }.store(in: &disposeBag)

    self.speedSecondQuickActionButton.publisher(for: .touchUpInside)
      .sink { [weak self] _ in
        self?.setSliderSpeed(2)
      }.store(in: &disposeBag)

    self.speedThirdQuickActionButton.publisher(for: .touchUpInside)
      .sink { [weak self] _ in
        self?.setSliderSpeed(3)
      }.store(in: &disposeBag)

    self.decrementSpeedButton.publisher(for: .touchUpInside)
      .sink { [weak self] _ in
        guard let self = self,
              self.currentSpeedSlider.value > self.viewModel.getMinimumSpeedValue() else { return }

        self.setSliderSpeed(self.currentSpeedSlider.value - 0.05)
      }.store(in: &disposeBag)

    self.incrementSpeedButton.publisher(for: .touchUpInside)
      .sink { [weak self] _ in
        guard let self = self,
              self.currentSpeedSlider.value < self.viewModel.getMaximumSpeedValue() else { return }

        self.setSliderSpeed(self.currentSpeedSlider.value + 0.05)
      }.store(in: &disposeBag)
  }

  private func setSliderSpeed(_ value: Float) {
    self.currentSpeedSlider.accessibilityValue = "\(value)"
    self.currentSpeedSlider.value = value
    self.viewModel.handleSpeedChange(newValue: value)
  }

  @IBAction func done(_ sender: UIBarButtonItem?) {
    self.viewModel.dismiss()
  }

  @IBAction func handleMoreAction(_ sender: UIButton) {
    viewModel.showMoreControls()
  }
}

extension PlayerControlsViewController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.view.backgroundColor = theme.systemBackgroundColor
    self.separatorView.backgroundColor = theme.secondaryColor

    self.currentSpeedLabel.textColor = theme.primaryColor
    self.boostLabel.textColor = theme.primaryColor
    self.boostSwitchControl.tintColor = theme.linkColor

    self.currentSpeedSlider.minimumTrackTintColor = theme.linkColor
    self.currentSpeedSlider.maximumTrackTintColor = theme.separatorColor

    self.speedFirstQuickActionButton.tintColor = theme.primaryColor
    self.speedSecondQuickActionButton.tintColor = theme.primaryColor
    self.speedThirdQuickActionButton.tintColor = theme.primaryColor
    self.decrementSpeedButton.tintColor = theme.primaryColor
    self.incrementSpeedButton.tintColor = theme.primaryColor

    self.moreButton.tintColor = theme.linkColor

    self.overrideUserInterfaceStyle = theme.useDarkVariant
    ? UIUserInterfaceStyle.dark
    : UIUserInterfaceStyle.light
  }
}
