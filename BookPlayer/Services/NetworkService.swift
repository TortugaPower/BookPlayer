//
//  NetworkService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 4/5/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import Alamofire
import Foundation

class NetworkService {
    static let shared = NetworkService()

    lazy var manager: SessionManager = {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.tortugapower.audiobookplayer.background")
        return Alamofire.SessionManager(configuration: configuration)
    }()

    var downloadRequest: DownloadRequest?

    public func download(from url: URL, completionHandler: @escaping (DefaultDownloadResponse) -> Void) {
        let destination: DownloadRequest.DownloadFileDestination = { _, _ in
            (FileManager.default.temporaryDirectory.appendingPathComponent("download-file-\(Date().timeIntervalSince1970)"), [.createIntermediateDirectories, .removePreviousFile])
        }

        self.manager.startRequestsImmediately = true

        let request = URLRequest(url: url)
        self.downloadRequest = self.manager.download(request, to: destination)
            .downloadProgress { progress in
                let percentage = String(format: "%.2f", progress.fractionCompleted * 100)
                NotificationCenter.default.post(name: .downloadProgress, object: nil, userInfo: ["progress": percentage])
            }
            .response { response in
                self.downloadRequest = nil

                if let res = response.response,
                    res.statusCode == 200,
                    let url = response.destinationURL,
                    let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first,
                    let suggestedFilename = res.suggestedFilename {
                    try? FileManager.default.moveItem(at: url, to: documentsUrl.appendingPathComponent(suggestedFilename))
                }

                completionHandler(response)
            }
    }
}
