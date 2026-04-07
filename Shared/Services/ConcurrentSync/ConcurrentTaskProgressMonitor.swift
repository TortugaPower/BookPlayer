//
//  ConcurrentTasksProgressMonitor.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 25/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftUI
import SwiftData

public enum ActiveTaskState: Equatable {
  case processing         // Indeterminate (API calls, updates)
  case progress(Double) // Determinate (Files, byte progress)
}

@Observable
@MainActor
public class TaskProgressTracker {
    var state: ActiveTaskState
    
    init(state: ActiveTaskState) {
        self.state = state
    }
}

@Observable
@MainActor
public class ConcurrentTaskProgressMonitor {
  // Shared instance so both the UI and the Orchestrator can access it easily
  public static let shared = ConcurrentTaskProgressMonitor()
  
  // A dictionary mapping the Task ID to a progress double (0.0 to 1.0)
  public var activeTasks: [String: TaskProgressTracker] = [:]
  
  func markAsProcessing(taskID: String) {
    if let tracker = activeTasks[taskID] {
      tracker.state = .processing
    } else {
      activeTasks[taskID] = TaskProgressTracker(state: .processing)
    }
  }
  
  func updateProgress(for taskID: String, progress: Double) {
    // We no longer mutate the dictionary! We just update the object's property.
    // This surgical update is what SwiftUI's observation engine craves.
    activeTasks[taskID]?.state = .progress(progress)
  }
  
  func clear(taskID: String) {
    activeTasks.removeValue(forKey: taskID)
  }
  
  public func isActive(taskID: String) -> Bool {
    return activeTasks.keys.contains(taskID)
  }
  
  public func isTaskState(taskID: String) -> ActiveTaskState? {
    return activeTasks[taskID]?.state ?? nil
  }
  
  public func getTaskProgress(taskID: String) -> Double {
    guard let myState = activeTasks[taskID]?.state else { return 0 }
            
    switch myState {
      case .processing:
      return 0
    case let .progress(progress):
      return progress
    }
  }
}
