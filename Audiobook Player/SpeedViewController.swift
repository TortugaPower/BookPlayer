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
    
    var speedArray:[Float] = [0.75, 1, 1.25, 1.5, 1.75, 2.00, 2.25, 2.5]
    var currentSpeed:Float!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.vfxBackgroundView.effect = UIBlurEffect(style: .light)
        self.tableView.tableFooterView = UIView()
    }
    
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    override var preferredStatusBarUpdateAnimation : UIStatusBarAnimation {
        return .slide
    }
    
    
    @IBAction func didPressClose(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension SpeedViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.speedArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SpeedViewCell", for: indexPath)
        let speed = self.speedArray[indexPath.row]
        
        cell.textLabel?.text = String(speed)
        cell.textLabel?.highlightedTextColor = UIColor.black
        
        if speed == self.currentSpeed {
            cell.accessoryType = .checkmark
        }else{
            cell.accessoryType = .none
        }
        
        if self.currentSpeed == speed {
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .top)
        }
        
        return cell
    }
}

extension SpeedViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let speed = self.speedArray[indexPath.row]
        self.currentSpeed = speed
        self.performSegue(withIdentifier: "selectedSpeedSegue", sender: self)
    }
}
