//
//  CarPlaySceneDelegate.swift
//  BookPlayer
//
//  Created by gianni.carlo on 27/3/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

#if !targetEnvironment(macCatalyst)
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
#endif
