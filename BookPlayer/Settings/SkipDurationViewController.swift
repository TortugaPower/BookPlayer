//
//  SkipDurationViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 14.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class SkipDurationViewController: UITableViewController {
    private let intervals: [TimeInterval] = [
        5.0,
        10.0,
        15.0,
        20.0,
        30.0,
        45.0,
        60.0,
        90.0,
        120.0,
        180.0,
        240.0,
        300.0
    ]

    var selectedInterval: TimeInterval!
    var didSelectInterval: ((_ selectedInterval: TimeInterval) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        // self.clearsSelectionOnViewWillAppear = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.intervals.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "IntervalCell", for: indexPath)
        let interval = self.intervals[indexPath.row]

        cell.textLabel?.text = self.formatDuration(interval)

        if interval == self.selectedInterval {
            cell.accessoryType = .checkmark
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let interval = self.intervals[indexPath.row]

        self.didSelectInterval?(interval)
        self.navigationController?.popViewController(animated: true)
    }
}
