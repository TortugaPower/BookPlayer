//
//  ImportViewController.swift
//  BookPlayer
//
//  Created by Murali Murugan on 7/26/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import GCDWebServers
import Themeable
import UIKit

final class ImportViewController: UITableViewController {
    private var webServer: GCDWebUploader?
    @IBOutlet private weak var ipAddress: UILabel!
    @IBOutlet private weak var bonjourServer: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpTheming()
        self.startWebServer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.updateUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.stopWebServer()
    }

    func startWebServer() {
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
        self.webServer = GCDWebUploader(uploadDirectory: documentsPath)

        guard
            let webServer = webServer,
            let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as? String,
            let build = Bundle.main.infoDictionary!["CFBundleVersion"] as? String
        else {
            return
        }

        webServer.header = "Book Player file uploader"
        webServer.footer = "Book Player - " + version + " - " + build
        webServer.prologue = "Please upload the book in a zipped file or upload one zip/mp3/m4b/m4a file at a time!"
        webServer.allowedFileExtensions = ["zip", "mp3", "m4a", "m4b"]
        webServer.allowHiddenItems = false
        webServer.delegate = self
        webServer.start()
    }

    private func updateUI() {
        guard let webServer = webServer else {
            return
        }

        if webServer.isRunning {
            self.ipAddress.text = webServer.serverURL?.absoluteString
        }
    }

    private func stopWebServer() {
        guard let webServer = webServer else {
            return
        }
        if webServer.isRunning {
            webServer.stop()
        }
    }
}

extension ImportViewController: Themeable {
    func applyTheme(_ theme: Theme) {
        self.ipAddress.textColor = theme.primaryColor
        self.bonjourServer.textColor = theme.primaryColor
        self.tableView.backgroundColor = theme.settingsBackgroundColor
        self.tableView.separatorColor = theme.separatorColor
        self.tableView.reloadData()
    }
}

extension ImportViewController: GCDWebUploaderDelegate {
    func webUploader(_: GCDWebUploader, didUploadFileAtPath path: String) {
        DataManager.processFile(at: URL(fileURLWithPath: path))
    }
}
