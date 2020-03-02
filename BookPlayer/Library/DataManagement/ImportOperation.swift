//
//  BookOperation.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 8/30/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Foundation
import IDZSwiftCommonCrypto
import ZipArchive

/**
 Process files located at a specific `URL`, renames it with the hash and moves it to the specified destination folder.
 The new file maintains the extension of the original `URL`
 */

public class ImportOperation: Operation {
    public let files: [FileItem]

    init(files: [FileItem]) {
        self.files = files
    }

    func handleZip(file: FileItem) {
        guard file.originalUrl.pathExtension == "zip" else { return }

        // Unzip to a temp directory
        let tempURL = file.destinationFolder.appendingPathComponent("tmp")

        try? FileManager.default.createDirectory(at: tempURL, withIntermediateDirectories: true, attributes: nil)

        SSZipArchive.unzipFile(atPath: file.originalUrl.path, toDestination: tempURL.path, progressHandler: nil) { _, success, error in
            defer {
                // Delete original zip file
                try? FileManager.default.removeItem(at: file.originalUrl)
            }

            guard success else {
                print("Extraction of ZIP archive failed with error:\(String(describing: error))")
                return
            }

            let tempItem = FileItem(originalUrl: tempURL, processedUrl: nil, destinationFolder: file.destinationFolder)

            self.handleDirectory(file: tempItem)
        }
    }

    func handleDirectory(file: FileItem) {
        let resourceKeys: [URLResourceKey] = [.creationDateKey, .isDirectoryKey]
        let enumerator = FileManager.default.enumerator(at: file.originalUrl,
                                                        includingPropertiesForKeys: resourceKeys,
                                                        options: [.skipsHiddenFiles], errorHandler: { (url, error) -> Bool in
                                                            print("directoryEnumerator error at \(url): ", error)
                                                            return true
        })!

        let documentsURL = DataManager.getDocumentsFolderURL()

        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "mp3" || fileURL.pathExtension == "m4a" || fileURL.pathExtension == "m4b" else { continue }

            let destinationURL = documentsURL.appendingPathComponent(fileURL.lastPathComponent)
            try? FileManager.default.moveItem(at: fileURL, to: destinationURL)
        }

        // Delete directory
        try? FileManager.default.removeItem(at: file.originalUrl)
    }

    public override func main() {
        for file in self.files {
            NotificationCenter.default.post(name: .processingFile, object: nil, userInfo: ["filename": file.originalUrl.lastPathComponent])

            guard file.originalUrl.pathExtension != "zip" else {
                handleZip(file: file)
                continue
            }

            guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.originalUrl.path) else {
                continue
            }

            if let type = attributes[.type] as? FileAttributeType, type == .typeDirectory {
                handleDirectory(file: file)
                continue
            }

            guard FileManager.default.fileExists(atPath: file.originalUrl.path),
                let inputStream = InputStream(url: file.originalUrl) else {
                continue
            }

            inputStream.open()

            autoreleasepool {
                let digest = Digest(algorithm: .md5)

                while inputStream.hasBytesAvailable {
                    var inputBuffer = [UInt8](repeating: 0, count: 1024)
                    inputStream.read(&inputBuffer, maxLength: inputBuffer.count)
                    _ = digest.update(byteArray: inputBuffer)
                }

                inputStream.close()

                let finalDigest = digest.final()

                let hash = hexString(fromArray: finalDigest)
                let ext = file.originalUrl.pathExtension
                let filename = hash + ".\(ext)"
                let destinationURL = file.destinationFolder.appendingPathComponent(filename)

                do {
                    if !FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.moveItem(at: file.originalUrl, to: destinationURL)
                        try (destinationURL as NSURL).setResourceValue(URLFileProtection.none, forKey: .fileProtectionKey)
                    } else {
                        try FileManager.default.removeItem(at: file.originalUrl)
                    }
                } catch {
                    fatalError("Fail to move file from \(file.originalUrl) to \(destinationURL)")
                }

                file.processedUrl = destinationURL
            }
        }
    }
}
