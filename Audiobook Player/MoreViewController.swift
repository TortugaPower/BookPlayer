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

extension MoreViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return MoreAction.actionNames.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MoreViewCell", for: indexPath)
        let action = MoreAction(rawValue: indexPath.row)
        
        cell.textLabel?.text = action?.actionName()
        cell.textLabel?.highlightedTextColor = UIColor.black
        
        return cell
    }
}

extension MoreViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let action = MoreAction(rawValue: indexPath.row)
        self.selectedAction = action
        self.performSegue(withIdentifier: "selectedActionSegue", sender: self)
    }
}

enum MoreAction: Int {
    case jumpToStart, markFinished
    
    static let actionNames = [
        jumpToStart : "Jump To Start", markFinished : "Mark as Finished"]
    
    func actionName() -> String {
        if let actionName = MoreAction.actionNames[self] {
            return actionName
        } else {
            return ""
        }
    }
}
