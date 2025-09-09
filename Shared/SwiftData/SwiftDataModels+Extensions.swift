//
//  SwiftDataModels+Extensions.swift
//  BookPlayer
//
//  Created by Gianni Carlo on [Current Date].
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import Foundation
import SwiftData

// MARK: - Dictionary Conversion Protocol

public protocol DictionaryConvertible {
  func toDictionaryPayload() -> [String: Any]
}

// MARK: - Extensions for SwiftData Models

extension UploadTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    var dict: [String: Any] = [
      "id": id,
      "relativePath": relativePath,
      "originalFileName": originalFileName,
      "title": title,
      "details": details,
      "currentTime": currentTime,
      "duration": duration,
      "percentCompleted": percentCompleted,
      "isFinished": isFinished,
      "orderRank": orderRank,
      "type": type
    ]
    
    // Handle optional values and sanitize infinite values
    if let speed = speed, speed.isFinite {
      dict["speed"] = speed
    }
    
    if let lastPlayDateTimestamp = lastPlayDateTimestamp, lastPlayDateTimestamp.isFinite {
      dict["lastPlayDateTimestamp"] = lastPlayDateTimestamp
    }
    
    return dict
  }
}

extension UpdateTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    var dict: [String: Any] = [
      "id": id,
      "relativePath": relativePath
    ]
    
    if let title = title { dict["title"] = title }
    if let details = details { dict["details"] = details }
    if let speed = speed, speed.isFinite { dict["speed"] = speed }
    if let currentTime = currentTime { dict["currentTime"] = currentTime }
    if let duration = duration { dict["duration"] = duration }
    if let percentCompleted = percentCompleted { dict["percentCompleted"] = percentCompleted }
    if let isFinished = isFinished { dict["isFinished"] = isFinished }
    if let orderRank = orderRank { dict["orderRank"] = orderRank }
    if let lastPlayDateTimestamp = lastPlayDateTimestamp, lastPlayDateTimestamp.isFinite {
      dict["lastPlayDateTimestamp"] = lastPlayDateTimestamp
    }
    if let type = type { dict["type"] = type }
    
    return dict
  }
}

extension MoveTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "relativePath": relativePath,
      "origin": origin,
      "destination": destination
    ]
  }
}

extension DeleteTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "relativePath": relativePath,
      "jobType": jobType.rawValue
    ]
  }
}

extension DeleteBookmarkTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "relativePath": relativePath,
      "time": time
    ]
  }
}

extension SetBookmarkTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    var dict: [String: Any] = [
      "id": id,
      "relativePath": relativePath,
      "time": time
    ]
    
    if let note = note {
      dict["note"] = note
    }
    
    return dict
  }
}

extension RenameFolderTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "relativePath": relativePath,
      "name": name
    ]
  }
}

extension ArtworkUploadTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "relativePath": relativePath
    ]
  }
}

