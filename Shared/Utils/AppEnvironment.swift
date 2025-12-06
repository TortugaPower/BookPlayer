//
//  AppEnvironment.swift
//  BookPlayer
//
//  Created by BookPlayer on 12/6/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation

public enum AppEnvironment {
  /// Checks if the app is running in a TestFlight environment
  public static var isTestFlight: Bool {
    #if DEBUG
    return false
    #else
    // Check if the app is installed via TestFlight
    guard let receiptURL = Bundle.main.appStoreReceiptURL else {
      return false
    }
    
    return receiptURL.lastPathComponent == "sandboxReceipt"
    #endif
  }
  
  /// Checks if in-app purchases should be enabled
  public static var isPurchaseEnabled: Bool {
    return !isTestFlight
  }
  
  /// Returns the current environment description for debugging
  public static var environmentDescription: String {
    if isTestFlight {
      return "TestFlight"
    }
    #if DEBUG
    return "Debug"
    #else
    return "Production"
    #endif
  }
}

