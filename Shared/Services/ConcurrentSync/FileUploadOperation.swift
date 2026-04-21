//
//  FileUploadOperation.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 26/3/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import Foundation
import Combine

class FileUploadOperation: AsyncOperation, @unchecked Sendable {
  
  // MARK: - Properties
  let fileURL: URL
  let remoteURL: URL
  let uuid: String
  
  // Inject whatever type 'self.client' is in your original code
  let client: NetworkClientProtocol
  
  // State management for the background task
  private var currentUploadTask: URLSessionTask?
  private var progressSubscriber: AnyCancellable?
  private var completionSubscriber: AnyCancellable?
  private var cellularDataObserver: NSKeyValueObservation?
  
  // MARK: - Init
  init(fileURL: URL, remoteURL: URL, uuid: String, client: NetworkClientProtocol = NetworkClient()) {
    self.fileURL = fileURL
    self.remoteURL = remoteURL
    self.uuid = uuid
    self.client = client
    super.init()
  }
  
  // MARK: - Execution
  override func main() {
    guard !isCancelled else {
      self.finish()
      return
    }
    
    // Spin up the async context
    Task {
      await startUploadTask()
    }
  }
  
  // MARK: - Upload Logic
  private func startUploadTask() async {
    // 1. Determine Session
    let allowCellular = UserDefaults.standard.bool(forKey: Constants.UserDefaults.allowCellularData)
    let session = allowCellular ? BPURLSession.shared.backgroundCellularSession : BPURLSession.shared.backgroundSession
    // 2. Create the Task
    let uploadTask = await self.client.uploadTask(
      fileURL,
      remoteURL: remoteURL,
      taskDescription: uuid,
      session: session
    )
    self.currentUploadTask = uploadTask
    
    // 3. Bind everything before resuming
    bindUploadObservers()
    bindCellularObserver()
    // 4. Fire!
    uploadTask.resume()
  }
  
  private func bindCellularObserver() {
    cellularDataObserver?.invalidate()
    
    // Assuming \.userSettingsAllowCellularData is an extension on UserDefaults
    cellularDataObserver = UserDefaults.standard.observe(
      \.userSettingsAllowCellularData,
       options: [.new]
    ) { [weak self] _, change in
      
      guard let self = self, change.newValue != nil else { return }
      
      // If the user toggles cellular data mid-flight, we cancel the current internal task.
      // (This triggers NSURLErrorCancelled in the completion subscriber).
      self.currentUploadTask?.cancel()
      
      // Recursively restart the upload using the new session!
      Task {
        await self.startUploadTask()
      }
    }
  }
  
  private func bindUploadObservers() {
    progressSubscriber?.cancel()
    progressSubscriber = BPURLSession.shared.progressPublisher
      .sink { [weak self] (path, progress) in
        guard let self = self else { return }
        // CRITICAL: Only report progress if this event belongs to THIS operation
        if uuid == self.uuid {
          self.onProgress?(progress)
        }
      }
    
    completionSubscriber?.cancel()
    completionSubscriber = BPURLSession.shared.completionPublisher
      .sink { [weak self] (task, error) in
        guard let self = self else { return }
        
        // CRITICAL: Ensure this completion event belongs to this specific task
        guard task.taskDescription == self.uuid else { return }
        
        // We've hit a terminal state for this attempt, so clean up the KVO
        self.cellularDataObserver?.invalidate()
        
        if let nserror = error as? NSError,
           nserror.domain == NSURLErrorDomain,
           nserror.code == NSURLErrorCancelled {
          // Do nothing! The cellular KVO observer cancelled this task
          // and is already spinning up a new one via startUploadTask().
          
        } else if let error = error {
          // Actual Failure
          print("Upload failed for \(self.uuid): \(error)")
          self.didSucceed = false
          self.finish()
          
        } else {
          // Success!
          // (You could run your handleUploadFinished logic here if it does extra database work)
          Task { @MainActor in
            do {
              try FileManager.default.removeItem(at: self.fileURL)
            } catch {
              print("Failed to delete hard link for \(self.uuid): \(error.localizedDescription)")
            }
          }
          self.didSucceed = true
          self.finish()
        }
      }
  }
  
  // MARK: - Cleanup
  // If the Orchestrator cancels the operation entirely, we must sever all ties.
  override func cancel() {
    super.cancel()
    currentUploadTask?.cancel()
    cellularDataObserver?.invalidate()
    progressSubscriber?.cancel()
    completionSubscriber?.cancel()
  }
}
