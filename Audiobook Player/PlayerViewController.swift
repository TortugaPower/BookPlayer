//
//  PlayerViewController.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 7/5/16.
//  Copyright © 2016 Tortuga Power. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import Chameleon
import MBProgressHUD

class PlayerViewController: UIViewController, AVAudioPlayerDelegate {
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var rewindButton: UIButton!
    
    @IBOutlet weak var maxTimeLabel: UILabel!
    @IBOutlet weak var currentTimeLabel: UILabel!
    
    @IBOutlet weak var timeSeparator: UILabel!
    var audioPlayer:AVAudioPlayer?
    
    @IBOutlet weak var leftVerticalView: UIView!
    @IBOutlet weak var sliderView: UISlider!
    
    @IBOutlet weak var percentageLabel: UILabel!
    
    //keep in memory current Documents folder
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
    
    var namesArray:[String]!
    var fileURL:NSURL!
    
    //keep in memory images to toggle play/pause
    let playImage = UIImage(named: "playButton")
    let pauseImage = UIImage(named: "pauseButton")
    
    //current item to play
    var playerItem:AVPlayerItem!
    
    //timer to update labels about time
    var timer:NSTimer!
    
    //book identifier for `NSUserDefaults`
    var identifier:String!
    
    //MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //set UI colors
        let colors:[UIColor] = [
            UIColor.flatGrayColorDark(),
            UIColor.flatSkyBlueColorDark()
        ]
        self.view.backgroundColor = GradientColor(.Radial, frame: view.frame, colors: colors)
        self.leftVerticalView.backgroundColor = UIColor.flatRedColor()
        self.maxTimeLabel.textColor = UIColor.flatWhiteColorDark()
        self.authorLabel.textColor = UIColor.flatWhiteColorDark()
        self.timeSeparator.textColor = UIColor.flatWhiteColorDark()
        
        self.setStatusBarStyle(UIStatusBarStyleContrast)
        
        //load book metadata
        self.titleLabel.text = AVMetadataItem.metadataItemsFromArray(self.playerItem.asset.metadata, withKey: AVMetadataCommonKeyTitle, keySpace: AVMetadataKeySpaceCommon).first?.value?.copyWithZone(nil) as? String
        
        self.authorLabel.text = AVMetadataItem.metadataItemsFromArray(self.playerItem.asset.metadata, withKey: AVMetadataCommonKeyArtist, keySpace: AVMetadataKeySpaceCommon).first?.value?.copyWithZone(nil) as? String
        
        let artwork = AVMetadataItem.metadataItemsFromArray(self.playerItem.asset.metadata, withKey: AVMetadataCommonKeyArtwork, keySpace: AVMetadataKeySpaceCommon).first?.value?.copyWithZone(nil) as! NSData
        
        let title = self.titleLabel.text?.stringByReplacingOccurrencesOfString(" ", withString: "_") ?? "defaulttitle"
        let author = self.authorLabel.text?.stringByReplacingOccurrencesOfString(" ", withString: "_") ?? "defaultauthor"
        
        self.identifier = title+author
        
        //set initial state for slider
        self.sliderView.setThumbImage(UIImage(), forState: .Normal)
        self.sliderView.tintColor = UIColor.flatLimeColorDark()
        self.sliderView.maximumValue = 100
        self.sliderView.value = 0
        
        //set percentage label to stored value
        let currentPercentage = NSUserDefaults.standardUserDefaults().stringForKey(self.identifier+"_percentage") ?? "0%"
        self.percentageLabel.text = currentPercentage
        
        MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        
        //load data on background thread
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            
            let mediaArtwork = MPMediaItemArtwork(image: UIImage(data: artwork) ?? UIImage())
            
            //try loading the data of the book
            guard let data = NSFileManager.defaultManager().contentsAtPath(self.fileURL.path!) else {
                //show error on main thread
                dispatch_async(dispatch_get_main_queue(), {
                    MBProgressHUD.hideHUDForView(self.view, animated: true)
                    self.showAlert(nil, message: "Problem loading mp3 data", style: .Alert)
                })
                
                return
            }
            
            //try loading the player
            self.audioPlayer = try? AVAudioPlayer(data: data)
            
            guard let audioplayer = self.audioPlayer else {
                //show error on main thread
                dispatch_async(dispatch_get_main_queue(), {
                    MBProgressHUD.hideHUDForView(self.view, animated: true)
                    self.showAlert(nil, message: "Problem loading player", style: .Alert)
                })
                return
            }
            
            //update UI on main thread
            dispatch_async(dispatch_get_main_queue(), {
                
                //set book metadata for lockscreen and control center
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = [
                    MPMediaItemPropertyTitle: self.titleLabel.text!,
                    MPMediaItemPropertyArtist: self.authorLabel.text!,
                    MPMediaItemPropertyPlaybackDuration: audioplayer.duration,
                    MPMediaItemPropertyArtwork: mediaArtwork
                ]
                
                //get stored value for current time of book
                let currentTime = NSUserDefaults.standardUserDefaults().integerForKey(self.identifier)
                
                //update UI if needed and set player to stored time
                if currentTime > 0 {
                    let formattedCurrentTime = self.formatTime(currentTime)
                    self.currentTimeLabel.text = formattedCurrentTime
                    
                    audioplayer.currentTime = NSTimeInterval(currentTime)
                }
                
                //update max duration label of book
                let maxDuration = Int(audioplayer.duration)
                self.maxTimeLabel.text = self.formatTime(maxDuration)
                
                //play audio automatically
                if let rootVC = self.navigationController?.viewControllers.first as? ListBooksViewController {
                    rootVC.didPressPlay(self.playButton)
                }
                
                MBProgressHUD.hideHUDForView(self.view, animated: true)
            })
        }
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //hide navigation bar for this controller
        self.navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func preferredStatusBarUpdateAnimation() -> UIStatusBarAnimation {
        return .Slide
    }
}

extension PlayerViewController {
    
    //skip time forward
    @IBAction func forwardPressed(sender: UIButton) {
        guard let audioplayer = self.audioPlayer else {
            return
        }
        let time = audioplayer.currentTime
        audioplayer.currentTime = time + 30
        //update time on lockscreen and control center
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime
        //trigger timer event
        self.updateTimer()
    }
    
    //skip time backwards
    @IBAction func rewindPressed(sender: UIButton) {
        guard let audioplayer = self.audioPlayer else {
            return
        }
        
        let time = audioplayer.currentTime
        audioplayer.currentTime = time - 30
        //update time on lockscreen and control center
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime
        //trigger timer event
        self.updateTimer()
    }
    
    //toggle play/pause of book
    @IBAction func playPressed(sender: UIButton) {
        guard let audioplayer = self.audioPlayer else {
            return
        }
        
        //pause player if it's playing
        if audioplayer.playing {
            //invalidate timer if needed
            if self.timer != nil {
                self.timer.invalidate()
            }
            
            //set pause state on player and control center
            audioplayer.stop()
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime
            try! AVAudioSession.sharedInstance().setActive(false)
            
            //update image for play button
            self.playButton.setImage(self.playImage, forState: .Normal)
            return
        }
        
        try! AVAudioSession.sharedInstance().setActive(true)
        
        //create timer if needed
        if self.timer == nil || (self.timer != nil && !self.timer.valid) {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
            NSRunLoop.mainRunLoop().addTimer(self.timer, forMode: NSRunLoopCommonModes)
        }
        
        //set play state on player and control center
        audioplayer.play()
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1
        
        //update image for play button
        self.playButton.setImage(self.pauseImage, forState: .Normal)
    }
    
    //timer callback (called every second)
    func updateTimer() {
        guard let audioplayer = self.audioPlayer else {
            return
        }
        
        let currentTime = Int(audioplayer.currentTime)
        
        //store state every 2 seconds, I/O can be expensive
        if currentTime % 2 == 0 {
            NSUserDefaults.standardUserDefaults().setInteger(currentTime, forKey: self.identifier)
        }
        
        //update current time label
        let timeText = self.formatTime(currentTime)
        self.currentTimeLabel.text = timeText
        
        //calculate book read percentage based on current time
        let percentage = (Float(currentTime) / Float(audioplayer.duration)) * 100
        self.sliderView.value = percentage
        
        let percentageString = String(Int(percentage))+"%"
        self.percentageLabel.text = percentageString
        
        //FIXME: this should only be updated when there's change to current percentage
        NSUserDefaults.standardUserDefaults().setObject(percentageString, forKey: self.identifier+"_percentage")
        
    }
    
    //utility function to transform seconds to format HH:MM:SS
    func formatTime(time:Int) -> String {
        let hours = Int(time / 3600)
        
        let remaining = Float(time - (hours * 3600))
        
        let minutes = Int(remaining / 60)
        
        let seconds = Int(remaining - Float(minutes * 60))

        var formattedTime = String(format:"%02d:%02d", minutes, seconds)
        if hours > 0 {
            formattedTime = String(format:"%02d:"+formattedTime, hours)
        }
        
        return formattedTime
    }
    
}