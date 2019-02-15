//
//  ThemeProvider.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Themeable
import UIKit

final class ThemeManager: ThemeProvider {
    static let shared = ThemeManager()

    var library: Library! {
        didSet {
            guard let theme = library.currentTheme else {
                //handle prepopulating
                return
            }

            self.theme = SubscribableValue<Theme>(value: theme)
        }
    }

    private var theme: SubscribableValue<Theme>!
    var availableThemes: [Theme] {
        return self.library.availableThemes?.array as? [Theme] ?? []
    }

    /// The current theme that is active
    var currentTheme: Theme {
        get {
            return self.theme.value
        }
        set {
            self.setNewTheme(newValue)
            self.library.currentTheme = newValue
            DataManager.saveContext()
        }
    }

    private lazy var formatter = NumberFormatter()

    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(self.brightnessChanged(_:)), name: .UIScreenBrightnessDidChange, object: nil)
        self.formatter.maximumFractionDigits = 2
    }

    @objc private func brightnessChanged(_ notification: Notification) {
        guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeBrightnessEnabled.rawValue) else { return }

        let threshold = UserDefaults.standard.float(forKey: Constants.UserDefaults.themeBrightnessThreshold.rawValue)

        let brightness = (UIScreen.main.brightness * 100).rounded() / 100

        // TODO: replace this when the dark variant refactor is done
        let theme = brightness <= CGFloat(threshold)
            ? self.availableThemes[1]
            : self.availableThemes[0]

        guard self.currentTheme != theme else { return }

        self.currentTheme = theme
    }

    private func setNewTheme(_ newTheme: Theme) {
        let window = UIApplication.shared.delegate!.window!!
        UIView.transition(with: window,
                          duration: 0.3,
                          options: [.transitionCrossDissolve],
                          animations: {
                              self.theme.value = newTheme
                          },
                          completion: nil)
    }

    /// Subscribe to be notified when the theme changes. Handler will be
    /// remove from subscription when `object` is deallocated.
    func subscribeToChanges(_ object: AnyObject, handler: @escaping (Theme) -> Void) {
        self.theme.subscribe(object, using: handler)
    }
}

extension Themeable where Self: AnyObject {
    var themeProvider: ThemeManager {
        return ThemeManager.shared
    }
}
