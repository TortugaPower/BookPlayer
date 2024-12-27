//
//  AppNavigationController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/21/18.
//  Copyright © 2018 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

class AppNavigationController: UINavigationController, Storyboarded {
  private lazy var separatorView: UIView = {
    let view = UIView()
    view.translatesAutoresizingMaskIntoConstraints = false
    view.isOpaque = true
    return view
  }()
  private var themedStatusBarStyle: UIStatusBarStyle?

  private var rootViewController: UIViewController? {
    return self.children.first
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return themedStatusBarStyle ?? super.preferredStatusBarStyle
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    // hide native separator
    let standardAppearance = UINavigationBarAppearance()
    standardAppearance.configureWithTransparentBackground()
    standardAppearance.backgroundColor = .clear
    navigationBar.scrollEdgeAppearance = standardAppearance
    navigationBar.compactAppearance = standardAppearance
    navigationBar.standardAppearance = standardAppearance

    // add custom separator
    self.navigationBar.addSubview(self.separatorView)

    NSLayoutConstraint.activate([
      separatorView.heightAnchor.constraint(equalToConstant: 0.5),
      separatorView.leadingAnchor.constraint(equalTo: navigationBar.leadingAnchor),
      separatorView.trailingAnchor.constraint(equalTo: navigationBar.trailingAnchor),
      separatorView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor),
    ])

    setUpTheming()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    self.handleSeparator()
  }

  func handleSeparator() {
    guard
      let rootVC = self.rootViewController,
      rootVC.navigationItem.largeTitleDisplayMode != .never else {
      return
    }
    if self.interactivePopGestureRecognizer!.state == .began {
      self.separatorView.alpha = 0.0
    } else if self.interactivePopGestureRecognizer!.state == .possible {
      self.separatorView.alpha = 1.0
    }
  }
}

extension AppNavigationController: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.themedStatusBarStyle = theme.useDarkVariant
    ? .lightContent
    : .default
    setNeedsStatusBarAppearanceUpdate()

    navigationBar.barTintColor = theme.systemBackgroundColor
    navigationBar.tintColor = theme.linkColor

    self.separatorView.backgroundColor = theme.separatorColor
    navigationBar.scrollEdgeAppearance?.backgroundColor = theme.systemBackgroundColor
    navigationBar.compactAppearance?.backgroundColor = theme.systemBackgroundColor
    navigationBar.standardAppearance.backgroundColor = theme.systemBackgroundColor

    let titleTextAttributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key.foregroundColor: theme.primaryColor
    ]
    navigationBar.titleTextAttributes = titleTextAttributes
    navigationBar.largeTitleTextAttributes = titleTextAttributes
    navigationBar.scrollEdgeAppearance?.titleTextAttributes = titleTextAttributes
    navigationBar.scrollEdgeAppearance?.largeTitleTextAttributes = titleTextAttributes
    navigationBar.compactAppearance?.titleTextAttributes = titleTextAttributes
    navigationBar.compactAppearance?.largeTitleTextAttributes = titleTextAttributes
    navigationBar.standardAppearance.titleTextAttributes = titleTextAttributes
    navigationBar.standardAppearance.largeTitleTextAttributes = titleTextAttributes

    self.view.backgroundColor = theme.systemBackgroundColor
  }
}
