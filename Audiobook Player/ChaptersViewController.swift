//
//  ChaptersViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 7/23/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import MediaPlayer

struct Chapter {
    var title:String
    var start:Int
    var duration:Int
    var index:Int
}

class ChaptersViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var vfxBackgroundView: UIVisualEffectView!
    
    var chapterArray:[Chapter]!
    var currentChapter:Chapter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.vfxBackgroundView.effect = UIBlurEffect(style: .Light)
        self.tableView.tableFooterView = UIView()
        self.tableView.reloadData()
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

extension ChaptersViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chapterArray.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("ChapterViewCell", forIndexPath: indexPath) as! ChapterViewCell
        let chapter = self.chapterArray[indexPath.row]
        cell.titleLabel.text = chapter.title
        cell.durationLabel.text = formatTime(chapter.start)
        cell.titleLabel.highlightedTextColor = UIColor.blackColor()
        cell.durationLabel.highlightedTextColor = UIColor.blackColor()
        
        if self.currentChapter.index == chapter.index {
            tableView.selectRowAtIndexPath(indexPath, animated: true, scrollPosition: .Top)
        }
        
        return cell
    }
}

extension ChaptersViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let chapter = self.chapterArray[indexPath.row]
        self.currentChapter = chapter
        self.performSegueWithIdentifier("selectedChapterSegue", sender: self)
    }
}

class ChapterViewCell: UITableViewCell {
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var durationLabel: UILabel!
    
}