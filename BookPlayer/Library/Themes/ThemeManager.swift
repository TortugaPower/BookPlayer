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

    private var theme = SubscribableValue<Theme>(value: .light)
    private var availableThemes: [Theme] = [.light, .dark]

    /// The current theme that is active
    var currentTheme: Theme {
        get {
            return self.theme.value
        }
        set {
            self.setNewTheme(newValue)
        }
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
