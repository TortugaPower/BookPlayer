//
//  ThemeProvider.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 12/21/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Themeable
import UIKit

final class ThemeManager: ThemeProvider {
  static let shared = ThemeManager()

  var libraryService: LibraryServiceProtocol!
  private var theme: SubscribableValue<SimpleTheme>!

  /// The current theme that is active
  var currentTheme: SimpleTheme {
    get {
      return self.theme.value
    }
    set {
      self.setNewTheme(newValue)

      if let title = newValue.title {
        self.libraryService.setLibraryTheme(with: title)
      }
    }
  }

  var useDarkVariant: Bool {
    didSet {
      self.setNewTheme(self.currentTheme)
    }
  }

  public func checkSystemMode() {
    guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue) else { return }

    self.useDarkVariant = UIScreen.main.traitCollection.userInterfaceStyle == .dark
  }

  private init() {
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.systemThemeVariantEnabled.rawValue) {
      self.useDarkVariant = UIScreen.main.traitCollection.userInterfaceStyle == .dark
    } else {
      self.useDarkVariant = UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeDarkVariantEnabled.rawValue)
    }

    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeBrightnessEnabled.rawValue) {
      let threshold = UserDefaults.standard.float(forKey: Constants.UserDefaults.themeBrightnessThreshold.rawValue)
      let brightness = (UIScreen.main.brightness * 100).rounded() / 100
      self.useDarkVariant = brightness <= CGFloat(threshold)
    }

    if var defaultTheme = ThemeManager.getLocalThemes().first {
      defaultTheme.useDarkVariant = self.useDarkVariant
      self.theme = SubscribableValue<SimpleTheme>(value: defaultTheme)
    }

    NotificationCenter.default.addObserver(self, selector: #selector(self.brightnessChanged(_:)), name: UIScreen.brightnessDidChangeNotification, object: nil)
  }

  public class func getLocalThemes() -> [SimpleTheme] {
    guard let themesFile = Bundle.main.url(forResource: "Themes", withExtension: "json"),
          let data = try? Data(contentsOf: themesFile, options: .mappedIfSafe),
          let themes = try? JSONDecoder().decode([SimpleTheme].self, from: data) else {
            return []
          }

    return themes
  }

  @objc private func brightnessChanged(_ notification: Notification) {
    guard UserDefaults.standard.bool(forKey: Constants.UserDefaults.themeBrightnessEnabled.rawValue) else { return }

    let threshold = UserDefaults.standard.float(forKey: Constants.UserDefaults.themeBrightnessThreshold.rawValue)
    let brightness = (UIScreen.main.brightness * 100).rounded() / 100
    let shouldUseDarkVariant = brightness <= CGFloat(threshold)

    if shouldUseDarkVariant != self.useDarkVariant {
      self.useDarkVariant = shouldUseDarkVariant
    }
  }

  private func setNewTheme(_ newTheme: SimpleTheme) {
    let newTheme = SimpleTheme(with: newTheme, useDarkVariant: self.useDarkVariant)
    let window = UIApplication.shared.delegate!.window!!
    UIView.transition(with: window,
                      duration: 0.3,
                      options: [.transitionCrossDissolve],
                      animations: { self.theme.value = newTheme },
                      completion: nil)
  }

  /// Subscribe to be notified when the theme changes. Handler will be
  /// remove from subscription when `object` is deallocated.
  func subscribeToChanges(_ object: AnyObject, handler: @escaping (SimpleTheme) -> Void) {
    self.theme.subscribe(object, using: handler)
  }
}

extension Themeable where Self: AnyObject {
  var themeProvider: ThemeManager {
    return ThemeManager.shared
  }
}
