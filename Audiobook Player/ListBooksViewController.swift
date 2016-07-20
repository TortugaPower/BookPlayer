//
//  ListBooksViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 7/7/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import Chameleon

class ListBooksViewController: UIViewController, UIGestureRecognizerDelegate {
    
    @IBOutlet weak var emptyListContainerView: UIView!
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var footerView: UIView!
    @IBOutlet weak var footerImageView: UIImageView!
    @IBOutlet weak var footerTitleLabel: UILabel!
    @IBOutlet weak var footerHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var footerPlayButton: UIButton!
    
    //keep in memory images to toggle play/pause
    let miniPlayImage = UIImage(named: "miniPlayButton")
    let miniPauseButton = UIImage(named: "miniPauseButton")
    
    //keep reference to player to know if there's an book loaded
    var playerViewController:PlayerViewController?
    
    var listBooks:[String] = []
    
    //TableView's datasource
    var itemArray:[AVPlayerItem] = []
    var urlArray:[NSURL] = []
    //keep in memory current Documents folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //enables pop gesture on pushed controller
        self.navigationController!.interactivePopGestureRecognizer!.delegate = self
        
        //fixed tableview having strange offset
        self.edgesForExtendedLayout = UIRectEdge.None

        //set colors
        self.navigationController?.navigationBar.barTintColor = UIColor.flatSkyBlueColor()
        self.footerView.backgroundColor = UIColor.flatSkyBlueColor()
        
        self.tableView.tableFooterView = UIView()
        
        //set external control listeners
        let skipForward = MPRemoteCommandCenter.sharedCommandCenter().skipForwardCommand
        skipForward.enabled = true
        skipForward.addTarget(self, action: #selector(self.forwardPressed(_:)))
        skipForward.preferredIntervals = [30]
        
        let skipRewind = MPRemoteCommandCenter.sharedCommandCenter().skipBackwardCommand
        skipRewind.enabled = true
        skipRewind.addTarget(self, action: #selector(self.rewindPressed(_:)))
        skipRewind.preferredIntervals = [30]
        
        let playCommand = MPRemoteCommandCenter.sharedCommandCenter().playCommand
        playCommand.enabled = true
        playCommand.addTarget(self, action: #selector(self.didPressPlay(_:)))
        
        let pauseCommand = MPRemoteCommandCenter.sharedCommandCenter().pauseCommand
        pauseCommand.enabled = true
        pauseCommand.addTarget(self, action: #selector(self.didPressPlay(_:)))
        
        //set tap handler to show detail on tap on footer view
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.didPressShowDetail(_:)))
        self.footerView.addGestureRecognizer(tapRecognizer)
        
        //register to audio-interruption notifications
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(self.handleAudioInterruptions(_:)), name: AVAudioSessionInterruptionNotification, object: nil)
        
        //load local files
        self.loadFiles()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        //show navigation bar for this controller
        self.navigationController?.setNavigationBarHidden(false, animated: true)
        
        //check if audiobook is loaded
        guard let _ = self.playerViewController else {
            self.footerHeightConstraint.constant = 0
            return
        }
        
        //resize footer view
        self.footerHeightConstraint.constant = 55
        
        self.setPlayImage()
        
        //reload selected cell to show accurate percentage label
        guard let index = self.tableView.indexPathForSelectedRow else {
            return
        }
        
        self.tableView.reloadRowsAtIndexPaths([index], withRowAnimation: .Automatic)
    }
    
    //no longer need to deregister observers for iOS 9+!
    //https://developer.apple.com/library/mac/releasenotes/Foundation/RN-Foundation/index.html#10_11NotificationCenter
    deinit {
        //for iOS 8
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    //Playback may be interrupted by calls. Handle pause
    func handleAudioInterruptions(notification:NSNotification){
        guard let playerVC = self.playerViewController, let audioPlayer = playerVC.audioPlayer else {
            return
        }
        if audioPlayer.playing {
            self.didPressPlay(self.footerPlayButton)
        }
    }
    
    /**
     *  Load local files and process them (rename them if necessary)
     *  Spaces in file names can cause side effects when trying to load the data
     */
    func loadFiles() {
        self.itemArray = []
        self.urlArray = []
        
        //get reference of all the files located inside the Documents folder
        let fileEnumerator = NSFileManager.defaultManager().enumeratorAtPath(self.documentsPath)!
        
        //iterate and process files
        for filename in fileEnumerator {
            var finalPath = self.documentsPath+"/"+(filename as! String)
            
            var originalURL:NSURL?
            
            if finalPath.containsString(" ") {
                originalURL = NSURL(fileURLWithPath: finalPath)
                finalPath = finalPath.stringByReplacingOccurrencesOfString(" ", withString: "_")
            }
            
            let fileURL = NSURL(fileURLWithPath: finalPath.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!)
            
            if let original = originalURL {
                try! NSFileManager.defaultManager().moveItemAtURL(original, toURL: fileURL)
            }
            
            //NOTE: AVPlayerItem from URL might not be ready right away, 
            //		it might be better to create it from a AVAsset
            
            //create AVPlayerItem to better access each files' metadata
            self.itemArray.append(AVPlayerItem(URL: fileURL))
            self.urlArray.append(fileURL)
        }
        
        //show/hide instructions view
        self.emptyListContainerView.hidden = self.itemArray.count > 0 ? true : false
        
        self.tableView.reloadData()
    }
    
    /**
     * Set play or pause image on button
     */
    func setPlayImage(){
        guard let playerVC = self.playerViewController, audioPlayer = playerVC.audioPlayer else{
            self.footerPlayButton.setImage(self.miniPlayImage, forState: .Normal)
            return
        }
        
        if audioPlayer.playing {
            self.footerPlayButton.setImage(self.miniPauseButton, forState: .Normal)
        }else{
            self.footerPlayButton.setImage(self.miniPlayImage, forState: .Normal)
        }
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return false
    }
    
    func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if(navigationController!.viewControllers.count > 1){
            return true
        }
        return false
    }
    @IBAction func didPressReload(sender: UIBarButtonItem) {
        self.loadFiles()
    }
    
    @IBAction func didPressPlay(sender: UIButton) {
        //check if audiobook is loaded
        guard let playerVC = self.playerViewController else {
            return
        }
        
        playerVC.playPressed(playerVC.playButton)
        
        self.setPlayImage()
    }
    
    func forwardPressed(sender: UIButton) {
        //check if audiobook is loaded
        guard let playerVC = self.playerViewController else {
            return
        }
        
        playerVC.forwardPressed(sender)
    }
    
    func rewindPressed(sender: UIButton) {
        //check if audiobook is loaded
        guard let playerVC = self.playerViewController else {
            return
        }
        
        playerVC.rewindPressed(sender)
    }
    
    @IBAction func didPressShowDetail(sender: UIButton) {
        guard let playerVC = self.playerViewController else {
            return
        }
        self.navigationController?.showViewController(playerVC, sender: self)
    }
}

extension ListBooksViewController: UITableViewDataSource {
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.itemArray.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("BookCellView", forIndexPath: indexPath) as! BookCellView
        
        let item = self.itemArray[indexPath.row]
        
        cell.titleLabel.text = AVMetadataItem.metadataItemsFromArray(item.asset.metadata, withKey: AVMetadataCommonKeyTitle, keySpace: AVMetadataKeySpaceCommon).first?.value?.copyWithZone(nil) as? String
        cell.titleLabel.highlightedTextColor = UIColor.blackColor()
        
        cell.authorLabel.text = AVMetadataItem.metadataItemsFromArray(item.asset.metadata, withKey: AVMetadataCommonKeyArtist, keySpace: AVMetadataKeySpaceCommon).first?.value?.copyWithZone(nil) as? String
        
        let artwork = AVMetadataItem.metadataItemsFromArray(item.asset.metadata, withKey: AVMetadataCommonKeyArtwork, keySpace: AVMetadataKeySpaceCommon).first?.value?.copyWithZone(nil) as! NSData
        
        //NOTE: we should have a default image for artwork
        cell.artworkImageView.image = UIImage(data: artwork) ?? UIImage()
        
        let title = cell.titleLabel.text?.stringByReplacingOccurrencesOfString(" ", withString: "_") ?? "defaulttitle"
        let author = cell.authorLabel.text?.stringByReplacingOccurrencesOfString(" ", withString: "_") ?? "defaultauthor"
        
        //load stored percentage value
        cell.completionLabel.text = NSUserDefaults.standardUserDefaults().stringForKey(title+author+"_percentage") ?? "0%"
        cell.completionLabel.textColor = UIColor.flatGreenColorDark()
        
        return cell
    }
}

extension ListBooksViewController: UITableViewDelegate {
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }
    
    func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        
        let deleteAction = UITableViewRowAction(style: .Default, title: "Delete") { (action, indexPath) in
            let alert = UIAlertController(title: "Confirmation", message: "Are you sure you would like to remove this audiobook?", preferredStyle: .Alert)
            
            alert.addAction(UIAlertAction(title: "No", style: .Cancel, handler: { action in
                tableView.setEditing(false, animated: true)
            }))
            alert.addAction(UIAlertAction(title: "Yes", style: .Destructive, handler: { action in
                self.itemArray.removeAtIndex(indexPath.row)
                let url = self.urlArray.removeAtIndex(indexPath.row)
                try! NSFileManager.defaultManager().removeItemAtURL(url)
                tableView.beginUpdates()
                tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .None)
                tableView.endUpdates()
                
                self.emptyListContainerView.hidden = self.itemArray.count > 0 ? true : false
            }))
            
            self.presentViewController(alert, animated: true, completion: nil)
        }
        
        deleteAction.backgroundColor = UIColor.redColor()
        
        return [deleteAction]
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
    }
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 86
    }
    
    func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        guard let index = tableView.indexPathForSelectedRow else {
            return indexPath
        }
        
        tableView.deselectRowAtIndexPath(index, animated: true)
        
        return indexPath
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        
        let item = self.itemArray[indexPath.row]
        let url = self.urlArray[indexPath.row]
        let cell = tableView.cellForRowAtIndexPath(indexPath) as! BookCellView
        
        guard let playerVC = self.playerViewController, audioPlayer = playerVC.audioPlayer else {
            //create new player
            self.loadPlayer(item, url: url, cell: cell, indexPath: indexPath)
            return
        }
        
        //check if player is for a different book
        if playerVC.playerItem != item {
            audioPlayer.stop()
            //replace player with new one
            self.loadPlayer(item, url: url, cell: cell, indexPath: indexPath)
            return
        }
        
        //show the current player
        self.navigationController?.pushViewController(playerVC, animated: true)
    }
    
    func loadPlayer(item:AVPlayerItem, url:NSURL, cell:BookCellView, indexPath:NSIndexPath) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        self.playerViewController = storyboard.instantiateViewControllerWithIdentifier("PlayerViewController") as? PlayerViewController
        
        self.playerViewController!.playerItem = item
        
        let url = self.urlArray[indexPath.row]
        self.playerViewController!.fileURL = url
        
        self.footerTitleLabel.text = cell.titleLabel.text! + " - " + cell.authorLabel.text!
        self.footerImageView.image = cell.artworkImageView.image
        
        self.navigationController?.pushViewController(self.playerViewController!, animated: true)
    }
}

class BookCellView: UITableViewCell {
    @IBOutlet weak var artworkImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var completionLabel: UILabel!
    
}