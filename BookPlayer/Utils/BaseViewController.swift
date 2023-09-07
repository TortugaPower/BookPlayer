//
//  BaseViewController.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

class BaseViewController<T: Coordinator, U: ViewModelProtocol>: UIViewController {
  var viewModel: U!

  override func accessibilityPerformEscape() -> Bool {
    self.viewModel.dismiss()
    return true
  }
}

@available(*, deprecated, message: "Use `TableViewControllerProtocol` instead.")
class BaseTableViewController<T: Coordinator, U: BaseViewModel<T>>: UITableViewController {
  var viewModel: U!
}

protocol TableViewControllerProtocol: UITableViewController {
  associatedtype VM: ViewModelProtocol
  var viewModel: VM! { get set }
}

@available(*, deprecated, message: "Use `ViewModelProtocol` instead.")
class BaseViewModel<T: Coordinator> {
  weak var coordinator: T!

  func dismiss() {
    self.coordinator.didFinish()
  }
}

protocol ViewModelProtocol {
  associatedtype C: Coordinator
  var coordinator: C! { get set }
}

extension ViewModelProtocol {
  func dismiss() {
    coordinator.didFinish()
  }
}
