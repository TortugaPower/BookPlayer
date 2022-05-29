//
//  AlertPresenter.swift
//  BookPlayer
//
//  Created by gianni.carlo on 27/5/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation

protocol AlertPresenter {
  func showAlert(_ title: String?, message: String?, completion: (() -> Void)?)
}
