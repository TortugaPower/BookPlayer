//
//  CloudSyncService.swift
//  BookPlayer
//
//  Created by Kevin Campuzano on 5/5/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import BackgroundTasks

class BPProcessingTask {
    
    private static var syncTaskIdentifier =
    "\(Bundle.main.configurationString(for: .bundleIdentifier)).background.db_sync"
    
    func sync(){
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BPProcessingTask.syncTaskIdentifier,
                                        using: nil) { task in
            guard let syncTask = task as? BGProcessingTask else { return }
            self.handleDbSync(task: syncTask)
        }
    }
    
    static func scheduleDatabaseSyncIfNeeded(){
        let now = Date()
        let nigthDateComponents = DateComponents(calendar: .current, hour: 23)
        let nextNightDate = Calendar.current.nextDate(after: now,
                                                      matching: nigthDateComponents,
                                                      matchingPolicy: .nextTime,
                                                      direction: .first)!
        
        let nextSyncDate = Calendar.current.date(byAdding: .minute, value: 1, to: nextNightDate)!
        let request = BGProcessingTaskRequest(identifier: BPProcessingTask.syncTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
         
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("error on sync: \(error)")
        }
    }
    
    func handleDbSync(task: BGProcessingTask) {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        /// Sync Data base, update to iCloud
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        /**
         Una vez finalizado el sync
         dentro del callback del sync con iCloud
         
         task.setTaskCompleted(success: true)
         */

//        syncOperation
//        queue.addOperation(syncOperation)
    }
    
}
