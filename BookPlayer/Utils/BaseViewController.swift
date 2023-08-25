//
//  BaseViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

class BaseViewController<T: Coordinator, U: BaseViewModel<T>>: UIViewController {
  var viewModel: U!
  
  override func accessibilityPerformEscape() -> Bool {
    self.viewModel.dismiss()
    return true
  }
}

class BaseTableViewController<T: Coordinator, U: BaseViewModel<T>>: UITableViewController {
  var viewModel: U!
}

class BaseViewModel<T: Coordinator> {
  weak var coordinator: T!
  
  func dismiss() {
    self.coordinator.didFinish()
  }
}
