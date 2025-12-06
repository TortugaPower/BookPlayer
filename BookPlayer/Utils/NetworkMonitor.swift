//
//  NetworkMonitor.swift
//  BookPlayer
//
//  Created by BookPlayer on 6/12/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import Network
import SwiftUI

/// Monitors network connectivity and provides information about the current connection type
@Observable
class NetworkMonitor {
  private let monitor = NWPathMonitor()
  private let queue = DispatchQueue(label: "NetworkMonitor")
  
  var isConnected: Bool = false
  var isConnectedViaWiFi: Bool = false
  var isConnectedViaCellular: Bool = false
  
  init() {
    startMonitoring()
  }
  
  deinit {
    stopMonitoring()
  }
  
  func startMonitoring() {
    monitor.pathUpdateHandler = { [weak self] path in
      DispatchQueue.main.async {
        self?.isConnected = path.status == .satisfied
        self?.isConnectedViaWiFi = path.usesInterfaceType(.wifi)
        self?.isConnectedViaCellular = path.usesInterfaceType(.cellular)
      }
    }
    monitor.start(queue: queue)
  }
  
  func stopMonitoring() {
    monitor.cancel()
  }
}

// MARK: - Environment Key

private struct NetworkMonitorKey: EnvironmentKey {
  static let defaultValue = NetworkMonitor()
}

extension EnvironmentValues {
  var networkMonitor: NetworkMonitor {
    get { self[NetworkMonitorKey.self] }
    set { self[NetworkMonitorKey.self] = newValue }
  }
}

