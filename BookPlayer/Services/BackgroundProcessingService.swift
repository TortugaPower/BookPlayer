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
            
            // Schedule for every night at 23:00
            let calendar = Calendar.current
            var dateComponents = DateComponents()
            dateComponents.hour = 23
            dateComponents.minute = 0
            
            let nextRun = calendar.nextDate(after: Date(), matching: dateComponents, matchingPolicy: .nextTime)!
            task.earliestBeginDate = nextRun
            
            try BGTaskScheduler.shared.submit(task)
            print("Task Scheduled for tonight at 23:00")
        } catch {
            print("Error on submit: \(error)")
        }
    }
    
    fileprivate static func uploadDBToCloud(task: BGProcessingTask){
        Task {
            await BackupService().saveAndUpdateIfNeeded()
            task.setTaskCompleted(success: true)
        }
    }
}
