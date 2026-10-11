//
//  AppHostingViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 13/8/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import SwiftUI

final class AppHostingViewController<Content: View>: UIHostingController<Content> {
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    OrientationLock.supportedOrientations()
  }
}
