//
//  SpeedManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Foundation

class SpeedManager: NSObject {
  static let shared = SpeedManager()

  var subscription: AnyCancellable?
  let speedOptions: [Float] = [3, 2.5, 2, 1.75, 1.5, 1.25, 1.15, 1.1, 1, 0.9, 0.75, 0.5]

  public private(set) var currentSpeed = CurrentValueSubject<Float, Never>(1.0)

  private override init() {
    super.init()

    self.bindCurrentBook()
  }

  private func bindCurrentBook() {
    guard let appDelegate = UIApplication.shared.delegate as? AppDelegate,
          let mainCoordinator = appDelegate.coordinator.getMainCoordinator() else { return }

    self.subscription = mainCoordinator.playerManager.$currentBook.sink { [weak self] currentBook in
      let useGlobalSpeed = UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue)
      let globalSpeed = UserDefaults.standard.float(forKey: "global_speed")
      let localSpeed = currentBook?.folder?.speed ?? currentBook?.speed ?? 1.0
      let speed = useGlobalSpeed ? globalSpeed : localSpeed

      self?.currentSpeed.value = speed > 0 ? speed : 1.0
    }
  }

  public func setSpeed(_ newValue: Float, currentBook: Book?) {
    currentBook?.folder?.speed = newValue
    currentBook?.speed = newValue

    // set global speed
    if UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue) {
        UserDefaults.standard.set(newValue, forKey: "global_speed")
    }

    self.currentSpeed.value = newValue
  }

  public func getSpeed() -> Float {
    return self.currentSpeed.value
  }
}
