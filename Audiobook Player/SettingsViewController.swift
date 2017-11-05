//
//  SettingsViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 5/29/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import UIKit

class SettingsViewController: UITableViewController {
    @IBOutlet weak var storageSizeLabel: UILabel!
    @IBOutlet weak var themeSwitch: UISwitch!
    @IBOutlet weak var smartRewindSwitch: UISwitch!
    
    let defaults:UserDefaults = UserDefaults.standard
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        smartRewindSwitch.addTarget(self, action: #selector(self.rewindToggleDidChange), for: .valueChanged)
        
        //set colors
        self.navigationController?.navigationBar.barTintColor = UIColor.flatSkyBlue()
        
        //Set initial switch positions
        smartRewindSwitch.setOn(defaults.bool(forKey: UserDefaultsConstants.smartRewindEnabled), animated: false)
        
//        FileManager
    }
    
    @objc func rewindToggleDidChange(){
        defaults.set(smartRewindSwitch.isOn, forKey:UserDefaultsConstants.smartRewindEnabled)
    }
    
    @IBAction func didPressClose(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
    //TODO: remove this once settings page is completed
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //hide all options except smart rewind
        switch section {
        case 0, 1:
            return 0
        default:
            return 1
        }
    }
}
