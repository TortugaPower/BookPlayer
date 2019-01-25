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
