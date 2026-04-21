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
      "type": type,
      "uuid": uuid
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
      "relativePath": relativePath,
      "uuid": uuid
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
      "destination": destination,
      "uuid": uuid
    ]
  }
}

extension DeleteTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "jobType": jobType.rawValue,
      "uuid": uuid as Any
    ]
  }
}

extension DeleteBookmarkTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "time": time,
      "uuid": uuid as Any
    ]
  }
}

extension SetBookmarkTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    var dict: [String: Any] = [
      "id": id,
      "uuid": uuid,
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
      "name": name,
      "uuid": uuid as Any
    ]
  }
}

extension ArtworkUploadTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "uuid": uuid as Any
    ]
  }
}

extension MatchUuidsTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "uuids": uuids
    ]
  }
}

extension UploadExternalResourceTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "uuid": uuid,
      "providerId": providerId,
      "providerName": providerName,
      "lastSyncedAt": lastSyncedAt as Any,
      "processedFile": processedFile,
      "syncStatus": syncStatus
    ]
  }
}

extension ExternalResourceToDownloadTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    return [
      "id": id,
      "uuid": uuid,
      "uploaded": uploaded
    ]
  }
}

extension ExternalUpdateTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    var dictionary: [String: Any] = [
      "id": id,
      "providerId": providerId,
      "providerName": providerName
    ]
    
    if let title {
      dictionary["title"] = title
    }
    
    if let details {
      dictionary["details"] = details
    }
    
    if let currentTime {
      dictionary["currentTime"] = currentTime
    }
    
    if let percentCompleted {
      dictionary["percentCompleted"] = percentCompleted
    }
    
    if let isFinished {
      dictionary["isFinished"] = isFinished
    }
    
    if let lastPlayDateTimestamp {
      dictionary["lastPlayDateTimestamp"] = lastPlayDateTimestamp
    }
    
    return dictionary
  }
}

extension ConcurrentUploadTaskModel: DictionaryConvertible {
  public func toDictionaryPayload() -> [String: Any] {
    var dictionary: [String: Any] = [
      "id": id,
      "uuid": uuid,
      "filePath": filePath
    ]
    
    if let remotePath {
      dictionary["remotePath"] = remotePath
    }
    
    return dictionary
  }
}
