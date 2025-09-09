//
//  TasksDataManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on [Current Date].
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftData
import Combine

public final class TasksDataManager {
  public let container: ModelContainer
  private let tasksCountSubject = CurrentValueSubject<Int, Never>(0)

  public init() {
    let schema = Schema([
      SyncTasksContainer.self,
      SyncTaskReferenceModel.self,
      UploadTaskModel.self,
      UpdateTaskModel.self,
      MoveTaskModel.self,
      DeleteTaskModel.self,
      DeleteBookmarkTaskModel.self,
      SetBookmarkTaskModel.self,
      RenameFolderTaskModel.self,
      ArtworkUploadTaskModel.self
    ])

    let storeURL = DataManager.getSyncTasksSwiftDataURL()
    let modelConfiguration = ModelConfiguration(url: storeURL, cloudKitDatabase: .none)

    container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
  }

  public func getTasksCount() -> Int {
    tasksCountSubject.value
  }

  public func observeTasksCount() -> AnyPublisher<Int, Never> {
    return tasksCountSubject
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
  
  public func notifyTasksChanged(context: ModelContext) {
    let descriptor = FetchDescriptor<SyncTasksContainer>()

    do {
      let containers = try context.fetch(descriptor)
      let count = containers.first?.tasks.count ?? 0
      tasksCountSubject.send(count)
    } catch {
      tasksCountSubject.send(0)
    }
  }
  
  public func deleteAllTasks(with context: ModelContext) throws {
    try context.delete(model: UploadTaskModel.self)
    try context.delete(model: UpdateTaskModel.self)
    try context.delete(model: MoveTaskModel.self)
    try context.delete(model: DeleteTaskModel.self)
    try context.delete(model: DeleteBookmarkTaskModel.self)
    try context.delete(model: SetBookmarkTaskModel.self)
    try context.delete(model: RenameFolderTaskModel.self)
    try context.delete(model: ArtworkUploadTaskModel.self)
    try context.delete(model: SyncTaskReferenceModel.self)
    try context.delete(model: SyncTasksContainer.self)

    try context.save()
  }

  public func deleteTaskModel(
    with id: String,
    jobType: SyncJobType,
    context: ModelContext
  ) throws {
    switch jobType {
    case .upload:
      let descriptor = FetchDescriptor<UploadTaskModel>(
        predicate: #Predicate<UploadTaskModel> { task in task.id == id }
      )
      if let task = try context.fetch(descriptor).first {
        context.delete(task)
      }

    case .update:
      let descriptor = FetchDescriptor<UpdateTaskModel>(
        predicate: #Predicate<UpdateTaskModel> { task in task.id == id }
      )
      if let task = try context.fetch(descriptor).first {
        context.delete(task)
      }

    case .move:
      let descriptor = FetchDescriptor<MoveTaskModel>(
        predicate: #Predicate<MoveTaskModel> { task in task.id == id }
      )
      if let task = try context.fetch(descriptor).first {
        context.delete(task)
      }

    case .delete, .shallowDelete:
      let descriptor = FetchDescriptor<DeleteTaskModel>(
        predicate: #Predicate<DeleteTaskModel> { task in task.id == id }
      )
      if let task = try context.fetch(descriptor).first {
        context.delete(task)
      }

    case .deleteBookmark:
      let descriptor = FetchDescriptor<DeleteBookmarkTaskModel>(
        predicate: #Predicate<DeleteBookmarkTaskModel> { task in task.id == id }
      )
      if let task = try context.fetch(descriptor).first {
        context.delete(task)
      }

    case .setBookmark:
      let descriptor = FetchDescriptor<SetBookmarkTaskModel>(
        predicate: #Predicate<SetBookmarkTaskModel> { task in task.id == id }
      )
      if let task = try context.fetch(descriptor).first {
        context.delete(task)
      }

    case .renameFolder:
      let descriptor = FetchDescriptor<RenameFolderTaskModel>(
        predicate: #Predicate<RenameFolderTaskModel> { task in task.id == id }
      )
      if let task = try context.fetch(descriptor).first {
        context.delete(task)
      }

    case .uploadArtwork:
      let descriptor = FetchDescriptor<ArtworkUploadTaskModel>(
        predicate: #Predicate<ArtworkUploadTaskModel> { task in task.id == id }
      )
      if let task = try context.fetch(descriptor).first {
        context.delete(task)
      }
    }
  }

  public func deleteReferenceModel(
    with id: String,
    jobType: SyncJobType,
    context: ModelContext
  ) throws {
    let descriptor = FetchDescriptor<SyncTaskReferenceModel>(
      predicate: #Predicate<SyncTaskReferenceModel> { task in task.taskID == id }
    )
    if let task = try context.fetch(descriptor).first {
      context.delete(task)
    }
  }

  // swiftlint:disable force_cast
  public func createTaskModel(
    for jobType: SyncJobType,
    with parameters: [String: Any],
    in context: ModelContext
  ) {
    switch jobType {
    case .upload:
      let task = UploadTaskModel(
        id: parameters["id"] as! String,
        relativePath: parameters["relativePath"] as! String,
        originalFileName: parameters["originalFileName"] as! String,
        title: parameters["title"] as! String,
        details: parameters["details"] as! String,
        speed: parameters["speed"] as? Double,
        currentTime: parameters["currentTime"] as! Double,
        duration: parameters["duration"] as! Double,
        percentCompleted: parameters["percentCompleted"] as! Double,
        isFinished: parameters["isFinished"] as! Bool,
        orderRank: parameters["orderRank"] as! Int16,
        lastPlayDateTimestamp: parameters["lastPlayDateTimestamp"] as? Double,
        type: parameters["type"] as! Int16
      )
      context.insert(task)

    case .update:
      let task = UpdateTaskModel(
        id: parameters["id"] as! String,
        relativePath: parameters["relativePath"] as! String,
        title: parameters["title"] as? String,
        details: parameters["details"] as? String,
        speed: parameters["speed"] as? Double,
        currentTime: parameters["currentTime"] as? Double,
        duration: parameters["duration"] as? Double,
        percentCompleted: parameters["percentCompleted"] as? Double,
        isFinished: parameters["isFinished"] as? Bool,
        orderRank: parameters["orderRank"] as? Int16,
        lastPlayDateTimestamp: parameters["lastPlayDateTimestamp"] as? Double,
        type: parameters["type"] as? Int16
      )
      context.insert(task)

    case .move:
      let task = MoveTaskModel(
        id: parameters["id"] as! String,
        relativePath: parameters["relativePath"] as! String,
        origin: parameters["origin"] as! String,
        destination: parameters["destination"] as! String
      )
      context.insert(task)

    case .delete, .shallowDelete:
      let task = DeleteTaskModel(
        id: parameters["id"] as! String,
        relativePath: parameters["relativePath"] as! String,
        jobType: SyncJobType(rawValue: parameters["jobType"] as! String)!
      )
      context.insert(task)

    case .deleteBookmark:
      let task = DeleteBookmarkTaskModel(
        relativePath: parameters["relativePath"] as! String,
        time: parameters["time"] as! Double
      )
      context.insert(task)

    case .setBookmark:
      let task = SetBookmarkTaskModel(
        id: parameters["id"] as! String,
        relativePath: parameters["relativePath"] as! String,
        time: parameters["time"] as! Double,
        note: parameters["note"] as? String
      )
      context.insert(task)

    case .renameFolder:
      let task = RenameFolderTaskModel(
        id: parameters["id"] as! String,
        relativePath: parameters["relativePath"] as! String,
        name: parameters["name"] as! String
      )
      context.insert(task)

    case .uploadArtwork:
      let task = ArtworkUploadTaskModel(
        id: parameters["id"] as! String,
        relativePath: parameters["relativePath"] as! String
      )
      context.insert(task)
    }
  }

  // swiftlint:enable force_cast

  public func getTaskModel(
    with id: String,
    jobType: SyncJobType,
    in context: ModelContext
  ) -> (any DictionaryConvertible)? {
    do {
      switch jobType {
      case .upload:
        let descriptor = FetchDescriptor<UploadTaskModel>(
          predicate: #Predicate<UploadTaskModel> { task in task.id == id }
        )
        return try context.fetch(descriptor).first

      case .update:
        let descriptor = FetchDescriptor<UpdateTaskModel>(
          predicate: #Predicate<UpdateTaskModel> { task in task.id == id }
        )
        return try context.fetch(descriptor).first

      case .move:
        let descriptor = FetchDescriptor<MoveTaskModel>(
          predicate: #Predicate<MoveTaskModel> { task in task.id == id }
        )
        return try context.fetch(descriptor).first

      case .delete, .shallowDelete:
        let descriptor = FetchDescriptor<DeleteTaskModel>(
          predicate: #Predicate<DeleteTaskModel> { task in task.id == id }
        )
        return try context.fetch(descriptor).first

      case .deleteBookmark:
        let descriptor = FetchDescriptor<DeleteBookmarkTaskModel>(
          predicate: #Predicate<DeleteBookmarkTaskModel> { task in task.id == id }
        )
        return try context.fetch(descriptor).first

      case .setBookmark:
        let descriptor = FetchDescriptor<SetBookmarkTaskModel>(
          predicate: #Predicate<SetBookmarkTaskModel> { task in task.id == id }
        )
        return try context.fetch(descriptor).first

      case .renameFolder:
        let descriptor = FetchDescriptor<RenameFolderTaskModel>(
          predicate: #Predicate<RenameFolderTaskModel> { task in task.id == id }
        )
        return try context.fetch(descriptor).first

      case .uploadArtwork:
        let descriptor = FetchDescriptor<ArtworkUploadTaskModel>(
          predicate: #Predicate<ArtworkUploadTaskModel> { task in task.id == id }
        )
        return try context.fetch(descriptor).first
      }
    } catch {
      return nil
    }
  }

  public func updateTaskModel(_ task: UpdateTaskModel, with parameters: [String: Any]) {
    if let title = parameters["title"] as? String { task.title = title }
    if let details = parameters["details"] as? String { task.details = details }
    if let speed = parameters["speed"] as? Double { task.speed = speed }
    if let currentTime = parameters["currentTime"] as? Double { task.currentTime = currentTime }
    if let duration = parameters["duration"] as? Double { task.duration = duration }
    if let percentCompleted = parameters["percentCompleted"] as? Double { task.percentCompleted = percentCompleted }
    if let isFinished = parameters["isFinished"] as? Bool { task.isFinished = isFinished }
    if let orderRank = parameters["orderRank"] as? Int16 { task.orderRank = orderRank }
    if let lastPlayDateTimestamp = parameters["lastPlayDateTimestamp"] as? Double {
      task.lastPlayDateTimestamp = lastPlayDateTimestamp
    }
    if let type = parameters["type"] as? Int16 { task.type = type }
  }
}
