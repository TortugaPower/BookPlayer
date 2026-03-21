//
//  ExternalSyncService.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 20/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//
import CoreData
/*
class ExternalSyncService {
  let context: NSManagedObjectContext
  let jellyfinService: JellyfinConnectionService
  
  init(context: NSManagedObjectContext) {
    self.context = context
    self.jellyfinService = JellyfinConnectionService()
  }
  
  // 1. PULL: Called on app launch or refresh
  func pullUpdatesFromRemotes(for book: LibraryItem) async {
    for resource in book.resourcesArray {
      if resource.providerName == "jellyfin" {
        // Fetch remote progress
        let remoteData = await jellyfinService.fetchItemDetails(for: resource.providerId)
        
        // Compare timestamps to decide who wins
        if remoteData.lastPlayed > book.lastModifiedAt {
          book.currentTime = remoteData.playbackPosition
          resource.lastSyncedAt = Date()
          resource.syncStatus = true
        }
      }
      // Add other cases here if you add more providers later (e.g., case "hardcover")
    }
    try? context.save()
  }
  
  // 2. PUSH: Called when playback pauses or stops
  func pushLocalProgressToRemotes(for book: LibraryItem) async {
    for resource in book.externalResourcesArray {
      // Only push if the resource is flagged as out-of-sync
      guard resource.syncStatus == false else { continue }
      
      if resource.providerName == "jellyfin" {
        let success = await jellyfinService.updateProgress(
          id: resource.providerItemId!,
          ticks: book.currentTime
        )
        
        if success {
          resource.lastSyncedAt = Date()
          resource.syncStatus = true
        }
      }
    }
    try? context.save()
  }
}
*/
