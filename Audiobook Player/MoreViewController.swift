//
//  MoreViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 7/23/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit

class MoreViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var vfxBackgroundView: UIVisualEffectView!
    
    var selectedAction:MoreAction!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.vfxBackgroundView.effect = UIBlurEffect(style: .Light)
        self.tableView.tableFooterView = UIView()
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func preferredStatusBarUpdateAnimation() -> UIStatusBarAnimation {
        return .Slide
    }
    
    
    @IBAction func didPressClose(sender: UIBarButtonItem) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}

extension MoreViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MoreAction.actionNames.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("MoreViewCell", forIndexPath: indexPath)
        let action = MoreAction(rawValue: indexPath.row)
        
        cell.textLabel?.text = action?.actionName()
        cell.textLabel?.highlightedTextColor = UIColor.blackColor()
        
        return cell
    }
}

extension MoreViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let action = MoreAction(rawValue: indexPath.row)
        self.selectedAction = action
        self.performSegueWithIdentifier("selectedActionSegue", sender: self)
    }
}

enum MoreAction: Int {
    case JumpToStart, MarkFinished
    
    static let actionNames = [
        JumpToStart : "Jump To Start", MarkFinished : "Mark as Finished"]
    
    func actionName() -> String {
        if let actionName = MoreAction.actionNames[self] {
            return actionName
        } else {
            return ""
        }
    }
}