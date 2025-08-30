//
//  AppTabBarController.swift
//  BookPlayer
//
//  Created by gianni.carlo on 11/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

class AppTabBarController: UITabBarController {
  let miniPlayer: MiniPlayerUIView
  let miniPlayerViewModel: MiniPlayerViewModel

  private var disposeBag = Set<AnyCancellable>()
  private var themedStatusBarStyle: UIStatusBarStyle?
  /// iPadOS 18 moves the regular tab bar to the navigation bar
  private let regularOffset: CGFloat = -24
  private var compactOffset: CGFloat {
    -tabBar.bounds.size.height + self.view.safeAreaInsets.bottom
  }
  private lazy var viewBottomConstraint = self.miniPlayer.bottomAnchor.constraint(
    equalTo: view.safeAreaLayoutGuide.bottomAnchor,
    constant: compactOffset
  )
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    if UserDefaults.standard.object(forKey: Constants.UserDefaults.orientationLock) != nil,
       let orientation = UIDeviceOrientation(rawValue: UserDefaults.standard.integer(forKey: Constants.UserDefaults.orientationLock)) {
      return (orientation == .landscapeLeft || orientation == .landscapeRight)
      ? .landscape
      : .portrait
    } else {
      return .all
    }
  }

  public var isMiniPlayerVisible: Bool { !self.miniPlayer.isHidden }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return themedStatusBarStyle ?? super.preferredStatusBarStyle
  }

  // MARK: - Initializer
  public init(miniPlayerViewModel: MiniPlayerViewModel) {
    self.miniPlayerViewModel = miniPlayerViewModel
    self.miniPlayer = Bundle.loadView(fromNib: "MiniPlayerView", withType: MiniPlayerUIView.self)

    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)

    if #available(iOS 18.0, *),
       UIDevice.current.userInterfaceIdiom == .pad,
       traitCollection.horizontalSizeClass != .compact {
      viewBottomConstraint.constant = regularOffset
    } else {
      viewBottomConstraint.constant = compactOffset
    }

    guard self.traitCollection.userInterfaceStyle != .unspecified else { return }

    ThemeManager.shared.checkSystemMode()
  }

  override func viewDidLoad() {
    setupMiniPlayer()
    bindObservers()
    setUpTheming()
  }

  func setupMiniPlayer() {
    self.miniPlayer.translatesAutoresizingMaskIntoConstraints = false
    self.miniPlayer.layer.shadowOffset = CGSize(width: 0.0, height: 3.0)
    self.miniPlayer.layer.shadowOpacity = 0.18
    self.miniPlayer.layer.shadowRadius = 9.0
    self.miniPlayer.clipsToBounds = false
    view.addSubview(self.miniPlayer)

    NSLayoutConstraint.activate([
      self.miniPlayer.heightAnchor.constraint(equalToConstant: 88),
      self.miniPlayer.leftAnchor.constraint(equalTo: view.leftAnchor),
      self.miniPlayer.rightAnchor.constraint(equalTo: view.rightAnchor),
      viewBottomConstraint,
    ])

    guard
      #available(iOS 18.0, *),
      UIDevice.current.userInterfaceIdiom == .pad
    else {
      return
    }

    if traitCollection.horizontalSizeClass == .compact {
      viewBottomConstraint.constant = compactOffset
    } else {
      viewBottomConstraint.constant = regularOffset
    }
  }

  func bindObservers() {
    self.miniPlayerViewModel.isPlayingObserver()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] isPlaying in
        self?.miniPlayer.playIconView.isPlaying = isPlaying
      }
      .store(in: &disposeBag)

    self.miniPlayerViewModel.currentItemInfo
      .receive(on: DispatchQueue.main)
      .sink { [weak self] item in
        guard let self = self else { return }

        guard let item = item else {
          self.miniPlayer.isHidden = true
          return
        }

        if self.miniPlayer.isHidden {
          self.animateView(self.miniPlayer, show: true)
        }

        self.miniPlayer.setupPlayerView(
          with: item.title,
          author: item.author,
          relativePath: item.relativePath
        )
      }.store(in: &disposeBag)

    self.miniPlayer.onPlayerTap = { [weak self] in
      self?.miniPlayerViewModel.showPlayer()
    }

    self.miniPlayer.onPlayPauseTap = { [weak self] in
      self?.miniPlayerViewModel.handlePlayPauseAction()
    }
  }
}

extension AppTabBarController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.themedStatusBarStyle = theme.useDarkVariant
    ? .lightContent
    : .default
    setNeedsStatusBarAppearanceUpdate()
    self.tabBar.backgroundColor = theme.systemBackgroundColor
    self.tabBar.barTintColor = theme.systemBackgroundColor
    self.tabBar.tintColor = theme.linkColor

    self.miniPlayer.layer.shadowColor = theme.primaryColor.cgColor
  }
}
