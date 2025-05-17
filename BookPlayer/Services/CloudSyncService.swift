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
    
//    func sync() async {
//        BGTaskScheduler.shared.register(forTaskWithIdentifier: BPProcessingTask.syncTaskIdentifier,
//                                        using: nil) { task in
//            guard let asyncTask = task as? BGProcessingTask else { return }
//            await self.handleDbSync(task: asyncTask)
//        }
//    }
    
    static func scheduleDatabaseSyncIfNeeded(){
//        let now = Date()
//        let nigthDateComponents = DateComponents(calendar: .current, hour: 23)
//        let nextNightDate = Calendar.current.nextDate(after: now,
//                                                      matching: nigthDateComponents,
//                                                      matchingPolicy: .nextTime,
//                                                      direction: .first)!
//        
//        let nextSyncDate = Calendar.current.date(byAdding: .minute, value: 1, to: nextNightDate)!
//        let request = BGProcessingTaskRequest(identifier: BPProcessingTask.syncTaskIdentifier)
//        request.requiresNetworkConnectivity = true
//        request.requiresExternalPower = false
//         
//        do {
//            try BGTaskScheduler.shared.submit(request)
//        } catch {
//            print("error on sync: \(error)")
//        }
    }
    
    func handleDbSync(task: BGProcessingTask) async {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        
        /// Sync Data base, update to iCloud
        
//            let newData = "newDataExtra"
//            if let newDataIntoData = newData.data(using: .utf8) {
//                let record = await CloudKitService().saveOnPrivateDB(item: newData,
//                                             data: newDataIntoData)
//                print(record?.recordID)
//            }
            
//            if let recordData = await CloudKitService().get(recordName: "5542ED5D-B861-4F48-A7D2-B5EE15DDC9D5")?.data,
//               let str = String(data: recordData, encoding: .utf8) {
//                print(str)
//            }
        
        
        task.expirationHandler = {
            queue.cancelAllOperations()
        }
        
        /**
         Una vez finalizado el sync
         dentro del callback del sync con iCloud
         
         task.setTaskCompleted(success: true)
         */
        
//        let lastOperation = op

//        syncOperation
//        queue.addOperation(syncOperation)
    }
    
}
