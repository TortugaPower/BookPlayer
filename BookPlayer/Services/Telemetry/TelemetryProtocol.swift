//
//  TelemetryProtocol.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 11/3/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import TelemetryClient
import UIKit

protocol TelemetryProtocol {
  func sendSignal(_ signal: TelemetrySignal, with params: [String: String]?)
}

extension TelemetryProtocol {
  func sendSignal(_ signal: TelemetrySignal, with params: [String: String]?) {
    // For the time being only allow tip jar screen and tip action event
    guard signal == .tipJarScreen || signal == .tipAction else { return }

    TelemetryManager.shared.send(signal.rawValue, with: params ?? [:])
  }
}
