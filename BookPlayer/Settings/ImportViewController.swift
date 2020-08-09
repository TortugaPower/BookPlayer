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
    @IBOutlet private weak var bonjourServer: UILabel!
    @IBOutlet weak var wifiSharingLabel: LocalizableLabel!
    @IBOutlet weak var serverIpAddress: UILabel!
    @IBOutlet weak var serverStatus: UISwitch!
    
    @IBAction func didTapStartServer(_ sender: Any) {
        if self.serverStatus.isOn {
            self.startWebServer()
            self.updateUI()
        } else {
            self.stopWebServer()
            self.serverIpAddress.text = "Inactive Server"
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpTheming()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.stopWebServer()
    }

    private func startWebServer() {
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

        if webServer.isRunning, self.serverStatus.isOn {
            self.serverIpAddress.text = webServer.serverURL?.absoluteString
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
        self.wifiSharingLabel.textColor = theme.primaryColor
        self.serverIpAddress.textColor = theme.primaryColor
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
