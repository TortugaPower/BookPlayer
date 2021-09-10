//
//  LibraryListCoordinator.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

class LibraryListCoordinator: ItemListCoordinator {
  override func start() {
    let vc = LibraryViewController.instantiate(from: .Main)
    vc.coordinator = self
    self.navigationController.pushViewController(vc, animated: false)
  }
}
