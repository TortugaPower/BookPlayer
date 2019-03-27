//
//  AppNavigationController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

class AppNavigationController: UINavigationController {
    private var separatorView: UIView!
    private var themedStatusBarStyle: UIStatusBarStyle?

    private var rootViewController: UIViewController? {
        return self.children.first
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return themedStatusBarStyle ?? super.preferredStatusBarStyle
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        //hide native separator
        self.navigationBar.shadowImage = UIImage()
        self.navigationBar.setBackgroundImage(UIImage(), for: .any, barMetrics: .default)

        //add custom separator
        self.separatorView = UIView(frame: CGRect(x: 0, y: navigationBar.frame.size.height - 0.5, width: navigationBar.frame.size.width, height: 0.5))
        self.separatorView.isOpaque = true
        self.separatorView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin]
        self.navigationBar.addSubview(self.separatorView)

        setUpTheming()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if #available(iOS 11.0, *) {
            self.handleSeparator()
        }
    }

    @available(iOS 11.0, *)
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
    func applyTheme(_ theme: Theme) {
        self.themedStatusBarStyle = theme.useDarkVariant
            ? .lightContent
            : .default
        setNeedsStatusBarAppearanceUpdate()

        navigationBar.barTintColor = theme.backgroundColor
        navigationBar.tintColor = theme.highlightColor
        navigationBar.titleTextAttributes = [
            NSAttributedString.Key.foregroundColor: theme.navigationTitleColor
        ]
        if #available(iOS 11.0, *) {
            navigationBar.largeTitleTextAttributes = [
                NSAttributedString.Key.foregroundColor: theme.navigationTitleColor
            ]
        }
        self.separatorView.backgroundColor = theme.separatorColor
        self.view.backgroundColor = theme.backgroundColor
    }
}
