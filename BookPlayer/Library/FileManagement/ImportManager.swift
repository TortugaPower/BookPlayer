//
//  ImportManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/10/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation

/**
 Handles the creation of ImportOperation objects.
 It waits a specified time wherein new files may be added before the operation is created
 */
class ImportManager {
    private let timeout = 2.0
    private var timer: Timer?
    private var files = [FileItem]()

    func process(_ fileUrl: URL, destinationFolder: URL) {
        guard !files.contains(where: { $0.originalUrl == fileUrl }) else { return }

        setupTimer()

        let file = FileItem(originalUrl: fileUrl, processedUrl: nil, destinationFolder: destinationFolder)
        files.append(file)

        NotificationCenter.default.post(name: .newFileUrl, object: self, userInfo: nil)
    }

    private func setupTimer() {
        timer?.invalidate()
        timer = Timer(timeInterval: timeout, target: self, selector: #selector(createOperation), userInfo: nil, repeats: false)
        RunLoop.main.add(timer!, forMode: RunLoopMode.commonModes)
    }

    @objc private func createOperation() {
        guard !files.isEmpty else { return }

        let operation = ImportOperation(files: files)

        files = []

        NotificationCenter.default.post(name: .importOperation, object: self, userInfo: ["operation": operation])
    }
}
