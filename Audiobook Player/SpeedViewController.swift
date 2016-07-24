//
//  SpeedViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 7/23/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit

class SpeedViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var vfxBackgroundView: UIVisualEffectView!
    
    var speedArray:[Float] = [0.75, 1, 1.25, 1.5, 1.75]
    var currentSpeed:Float!
    
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

extension SpeedViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.speedArray.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("SpeedViewCell", forIndexPath: indexPath)
        let speed = self.speedArray[indexPath.row]
        
        cell.textLabel?.text = String(speed)
        cell.textLabel?.highlightedTextColor = UIColor.blackColor()
        
        if speed == self.currentSpeed {
            cell.accessoryType = .Checkmark
        }else{
            cell.accessoryType = .None
        }
        
        if self.currentSpeed == speed {
            tableView.selectRowAtIndexPath(indexPath, animated: true, scrollPosition: .Top)
        }
        
        return cell
    }
}

extension SpeedViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let speed = self.speedArray[indexPath.row]
        self.currentSpeed = speed
        self.performSegueWithIdentifier("selectedSpeedSegue", sender: self)
    }
}