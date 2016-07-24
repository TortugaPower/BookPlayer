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
