//
//  CarPlaySceneDelegate.swift
//  BookPlayer
//
//  Created by gianni.carlo on 27/3/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import CarPlay

class CarPlaySceneDelegate: NSObject, CPTemplateApplicationSceneDelegate {
  let manager = CarPlayManager()

  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene,
                                didConnect interfaceController: CPInterfaceController) {
    manager.connect(interfaceController)
  }

  func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController) {
    manager.disconnect()
  }
}
