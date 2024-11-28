//
//  JellyfinAudiobookDetailsViewModel.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import JellyfinAPI

struct JellyfinAudiobookDetailsData {
  let artist: String?
  let filePath: String?
  let fileSize: Int?
  let runtimeInSeconds: TimeInterval?
  
  var fileSizeString: String {
    if let fileSize {
      ByteCountFormatter.string(
        fromByteCount: Int64(fileSize),
        countStyle: ByteCountFormatter.CountStyle.file
      )
    } else {
      "file_size_unknown".localized
    }
  }
  
  var runtimeString: String {
    if let runtimeInSeconds {
      return TimeParser.formatTotalDuration(runtimeInSeconds)
    } else {
      return "runtime_unknown".localized
    }
  }
}

protocol JellyfinAudiobookDetailsViewModelProtocol: ObservableObject {
  var item: JellyfinLibraryItem { get }
  var details: JellyfinAudiobookDetailsData? { get }
  
  @MainActor
  func fetchData()
  
  @MainActor
  func cancelFetchData()
}

class JellyfinAudiobookDetailsViewModel: JellyfinAudiobookDetailsViewModelProtocol {
  let item: JellyfinLibraryItem
  @Published var details: JellyfinAudiobookDetailsData?
  
  private var apiClient: JellyfinClient
  private var fetchTask: Task<(), any Error>?
  
  init(item: JellyfinLibraryItem, apiClient: JellyfinClient) {
    self.item = item
    self.apiClient = apiClient
  }
  
  @MainActor
  func fetchData() {
    guard fetchTask == nil else {
      return
    }
    
    fetchTask = Task {
      defer { fetchTask = nil }
      
      do {
        let response = try await apiClient.send(Paths.getItem(itemID: item.id))
        try Task.checkCancellation()
        
        let itemInfo = response.value
        let artist: String? = itemInfo.albumArtist
        let filePath: String? = itemInfo.mediaSources?.first?.path ?? itemInfo.path
        let fileSize: Int? = itemInfo.mediaSources?.first?.size
        let runtimeInSeconds: TimeInterval? = (itemInfo.runTimeTicks != nil) ? TimeInterval(itemInfo.runTimeTicks!) / 10000000.0 : nil
        
        await MainActor.run {
          self.details = JellyfinAudiobookDetailsData(artist: artist,
                                                      filePath: filePath,
                                                      fileSize: fileSize,
                                                      runtimeInSeconds: runtimeInSeconds)
        }
      } catch is CancellationError {
        // ignore
      } catch {
        Task { @MainActor in
          // TODO
          //self.showErrorAlert(message: error.localizedDescription)
        }
      }
    }
  }
  
  @MainActor
  func cancelFetchData() {
    fetchTask?.cancel()
    fetchTask = nil
  }
}
