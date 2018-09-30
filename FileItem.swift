//
//  FileItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/11/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import Foundation

public class FileItem {
    public var originalUrl: URL
    public var processedUrl: URL?
    public var destinationFolder: URL

    public init(originalUrl: URL, processedUrl: URL?, destinationFolder: URL) {
        self.originalUrl = originalUrl
        self.processedUrl = processedUrl
        self.destinationFolder = destinationFolder
    }
    public convenience init(_ url: URL, destinationFolder: URL) {
        self.init(originalUrl: url, processedUrl: nil, destinationFolder: destinationFolder)
    }
}
