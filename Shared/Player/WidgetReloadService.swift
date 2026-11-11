//
//  WidgetReloadService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/11/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import Foundation
import WidgetKit


public protocol WidgetReloadServiceProtocol {
  /// Reload all the registered widgets
  func reloadAllWidgets()
  /// Reload specific widget
  func reloadWidget(_ type: Constants.Widgets)
  /// Reload a specific widget
  /// Note: Widgets showing progress info are subject to be constantly updated, so it's better to just make one update
  func scheduleWidgetReload(of type: Constants.Widgets)
}

public class WidgetReloadService: WidgetReloadServiceProtocol {
  /// Reference to ongoing tasks
  private var referenceWorkItems = [
    Constants.Widgets: DispatchWorkItem
  ]()

  public init() {}

  public func reloadAllWidgets() {
    referenceWorkItems.values.forEach({
      $0.cancel()
    })
    referenceWorkItems = [:]
    WidgetCenter.shared.reloadAllTimelines()
  }

  public func reloadWidget(_ type: Constants.Widgets) {
    let referenceWorkItem = referenceWorkItems[type]

    referenceWorkItem?.cancel()

    WidgetCenter.shared.reloadTimelines(ofKind: type.rawValue)
  }

  public func scheduleWidgetReload(of type: Constants.Widgets) {
    let referenceWorkItem = referenceWorkItems[type]

    referenceWorkItem?.cancel()

    let workItem = DispatchWorkItem {
      WidgetCenter.shared.reloadTimelines(ofKind: type.rawValue)
    }

    referenceWorkItems[type] = workItem

    DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(5), execute: workItem)
  }
}
