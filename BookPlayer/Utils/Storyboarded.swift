//
//  Storyboarded.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

enum StoryboardName: String {
  case Main, Settings, Player
}

protocol Storyboarded {
  static func instantiate(from storyboard: StoryboardName) -> Self
}

extension Storyboarded where Self: UIViewController {
  static func instantiate(from storyboard: StoryboardName) -> Self {
    let storyboard = UIStoryboard(name: storyboard.rawValue, bundle: Bundle(for: self))
    // swiftlint:disable force_cast
    return storyboard.instantiateViewController(withIdentifier: String(describing: self)) as! Self
  }
}
