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
        TelemetryManager.shared.send(signal.rawValue, with: params ?? [:])
    }
}
