//
//  IntegrationConnectionFormViewModelProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation

protocol IntegrationConnectionFormViewModelProtocol: ObservableObject {
  var serverUrl: String { get set }
  var serverName: String { get set }
  var username: String { get set }
  var password: String { get set }
}
