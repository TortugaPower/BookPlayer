//
//  SyncTasksCountService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 27/2/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation

public protocol SyncTasksCountServiceProtocol {
  func observeTasksCount() -> AnyPublisher<Int, Never>
}

public class SyncTasksCountService: SyncTasksCountServiceProtocol {
  private let tasksDataManager: TasksDataManager

  public init(tasksDataManager: TasksDataManager) {
    self.tasksDataManager = tasksDataManager
  }

  public func observeTasksCount() -> AnyPublisher<Int, Never> {
    return tasksDataManager.observeTasksCount()
  }
}
