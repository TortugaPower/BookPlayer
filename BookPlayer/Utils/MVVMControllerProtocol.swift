//
//  MVVMControllerProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 30/10/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import UIKit

protocol MVVMControllerProtocol: UIViewController {
  associatedtype VM: ViewModelProtocol
  var viewModel: VM! { get set }
}

extension MVVMControllerProtocol {
  func accessibilityPerformEscape() -> Bool {
    self.viewModel.dismiss()
    return true
  }
}

protocol ViewModelProtocol {
  associatedtype C: Coordinator
  var coordinator: C! { get set }
}

extension ViewModelProtocol {
  func dismiss() {
    coordinator.flow.finishPresentation(animated: true)
  }
}
