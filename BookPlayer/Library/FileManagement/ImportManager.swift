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
        guard !self.files.contains(where: { $0.originalUrl == fileUrl }) else { return }

        self.setupTimer()

        let file = FileItem(originalUrl: fileUrl, processedUrl: nil, destinationFolder: destinationFolder)
        self.files.append(file)

        NotificationCenter.default.post(name: .newFileUrl, object: self, userInfo: nil)
    }

    private func setupTimer() {
        self.timer?.invalidate()
        self.timer = Timer(timeInterval: self.timeout, target: self, selector: #selector(self.createOperation), userInfo: nil, repeats: false)
        RunLoop.main.add(self.timer!, forMode: RunLoopMode.commonModes)
    }

    @objc private func createOperation() {
        guard !self.files.isEmpty else { return }

        self.files.sort(by: { $0.originalUrl.path < $1.originalUrl.path })

        let operation = ImportOperation(files: self.files)

        self.files = []

        NotificationCenter.default.post(name: .importOperation, object: self, userInfo: ["operation": operation])
    }
}
