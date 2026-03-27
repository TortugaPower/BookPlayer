//
//  ConcurrentTasksCountService.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 25/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Combine
import Foundation

public protocol ConcurrentTasksCountServiceProtocol {
  func observeConcurrentTasksCount() -> AnyPublisher<Int, Never>
}

public class ConcurrentTasksCountService: ConcurrentTasksCountServiceProtocol {
  private var tasksCountPublisher = CurrentValueSubject<Int?, Never>(nil)
  private let tasksDataManager: TasksDataManager

  public init(tasksDataManager: TasksDataManager) {
    self.tasksDataManager = tasksDataManager
  }

  public func observeConcurrentTasksCount() -> AnyPublisher<Int, Never> {
    return tasksDataManager.observeConcurrentTasksCount()
  }
}
