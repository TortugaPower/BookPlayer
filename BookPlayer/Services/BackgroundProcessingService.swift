//
//  BackgroundProcessingService.swift
//  BookPlayer
//
//  Created by Kevin Campuzano on 5/5/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import Foundation
import BackgroundTasks

class BackgroundProcessingService {
    
    private static var backupTaskIdentifier =
    "\(Bundle.main.configurationString(for: .bundleIdentifier)).background.db_backup"
    
    public static func backupDB(){
        BGTaskScheduler.shared.register(forTaskWithIdentifier: BackgroundProcessingService.backupTaskIdentifier,
                                        using: nil) { (task) in
            guard let bgProcessingTask = task as? BGProcessingTask else {
                fatalError()
            }
            
            BackgroundProcessingService.uploadDBToCloud(task: bgProcessingTask)
        }
        
        /// launch
        /// e -l objc -- (void)[[BGTaskScheduler sharedScheduler] _simulateLaunchForTaskWithIdentifier:@"background.db_backup"]

        do {
            let task = BGProcessingTaskRequest(identifier: BackgroundProcessingService.backupTaskIdentifier)
            task.requiresExternalPower = false
            task.requiresNetworkConnectivity = true
//            task.earliestBeginDate = Date()
            try BGTaskScheduler.shared.submit(task)
            print("Task Scheduled")
        } catch {
            print("Error on submit: \(error)")
        }
    }
    
    fileprivate static func uploadDBToCloud(task: BGProcessingTask){
        Task {
            await BackupService().saveAndUpdateIfNeeded()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            //
        }
    }
}
