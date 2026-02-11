//
//  Fonts.swift
//  BookPlayer
//
//  Created by gianni.carlo on 23/7/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import UIKit

/// Legacy UIFont definitions for UIKit code (ShareExtension, Watch, LoginDisclaimerView, FormButton)
/// For SwiftUI, use BPFont instead.
public struct Fonts {
  public static let title = UIFont.preferredFont(with: 16, style: .headline, weight: .semibold)
  public static let titleLarge = UIFont.preferredFont(with: 20, style: .largeTitle, weight: .semibold)
  public static let body = UIFont.preferredFont(with: 14, style: .body, weight: .regular)
  public static let headline = UIFont.preferredFont(forTextStyle: .headline)
}
