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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //set colors
        self.navigationController?.navigationBar.barTintColor = UIColor.flatSkyBlue()
        
//        FileManager
    }
    
    @IBAction func didPressClose(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true, completion: nil)
    }
    
}
