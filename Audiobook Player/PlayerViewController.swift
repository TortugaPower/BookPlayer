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

class PlayerViewController: UIViewController {
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var rewindButton: UIButton!
    
    @IBOutlet weak var maxTimeLabel: UILabel!
    @IBOutlet weak var currentTimeLabel: UILabel!
    
    @IBOutlet weak var timeSeparator: UILabel!
    var audioPlayer:AVAudioPlayer!
    
    @IBOutlet weak var leftVerticalView: UIView!
    @IBOutlet weak var sliderView: UISlider!
    
    @IBOutlet weak var percentageLabel: UILabel!
//    var completionPercentage
    
    
    let documentsPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true).first!
    var namesArray:[String]!
    var fileURL:NSURL!
    
    let playImage = UIImage(named: "playButton")
    let pauseImage = UIImage(named: "pauseButton")
    
    var playerItem:AVPlayerItem!
    var timer:NSTimer!
    
    var identifier:String!
    
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
        
        let currentPercentage = NSUserDefaults.standardUserDefaults().stringForKey(self.identifier+"_percentage") ?? "0%"
        self.percentageLabel.text = currentPercentage
        
        MBProgressHUD.showHUDAddedTo(self.view, animated: true)
        
        //load data on background thread
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            
            let mediaArtwork = MPMediaItemArtwork(image: UIImage(data: artwork) ?? UIImage())
            
            //try fetching the data of the book
            guard let data = NSFileManager.defaultManager().contentsAtPath(self.fileURL.path!) else {
                //do something
                dispatch_async(dispatch_get_main_queue(), {
                    MBProgressHUD.hideHUDForView(self.view, animated: true)
                    self.showAlert(nil, message: "Problem loading mp3 data", style: .Alert)
                })
                
                return
            }
            
            //try loading the player
            do{
                try self.audioPlayer = AVAudioPlayer(data: data)
            } catch {
                //do something
                dispatch_async(dispatch_get_main_queue(), {
                    MBProgressHUD.hideHUDForView(self.view, animated: true)
                    self.showAlert(nil, message: "Problem loading player", style: .Alert)
                })
                return
            }
            
            //update ui on main queue
            dispatch_async(dispatch_get_main_queue(), {
                
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = [
                    MPMediaItemPropertyTitle: self.titleLabel.text!,
                    MPMediaItemPropertyArtist: self.authorLabel.text!,
                    MPMediaItemPropertyPlaybackDuration: self.audioPlayer.duration,
                    MPMediaItemPropertyArtwork: mediaArtwork
                ]
                
                let currentTime = NSUserDefaults.standardUserDefaults().integerForKey(self.identifier)
                
                if currentTime > 0 {
                    let formattedCurrentTime = self.formatTime(currentTime)
                    self.currentTimeLabel.text = formattedCurrentTime
                    
                    self.audioPlayer.currentTime = NSTimeInterval(currentTime)
                }
                
                let maxDuration = Int(self.audioPlayer.duration)
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
    
    @IBAction func forwardPressed(sender: UIButton) {
        let time = self.audioPlayer.currentTime
        self.audioPlayer.currentTime = time + 30
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.audioPlayer.currentTime
        self.updateTimer()
    }
    
    @IBAction func rewindPressed(sender: UIButton) {
        let time = self.audioPlayer.currentTime
        self.audioPlayer.currentTime = time - 30
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.audioPlayer.currentTime
        self.updateTimer()
    }
    
    @IBAction func playPressed(sender: UIButton) {
        if self.audioPlayer.playing {
            if self.timer != nil {
                self.timer.invalidate()
            }
            
            self.audioPlayer.stop()
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.audioPlayer.currentTime
            
            try! AVAudioSession.sharedInstance().setActive(false)
            self.playButton.setImage(self.playImage, forState: .Normal)
            return
        }
        
        try! AVAudioSession.sharedInstance().setActive(true)

        if self.timer == nil || (self.timer != nil && !self.timer.valid) {
            self.timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
            NSRunLoop.mainRunLoop().addTimer(self.timer, forMode: NSRunLoopCommonModes)
        }
        self.audioPlayer.play()
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.audioPlayer.currentTime
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1
        self.playButton.setImage(self.pauseImage, forState: .Normal)
    }
    
    func updateTimer() {
        let currentTime = Int(self.audioPlayer.currentTime)
        
        if currentTime % 2 == 0 {
            NSUserDefaults.standardUserDefaults().setInteger(currentTime, forKey: self.identifier)
        }
        
        let timeText = self.formatTime(currentTime)
        
        self.currentTimeLabel.text = timeText
        
        let percentage = (Float(currentTime) / Float(self.audioPlayer.duration)) * 100
        self.sliderView.value = percentage
        
        let percentageString = String(Int(percentage))+"%"
        self.percentageLabel.text = percentageString
        
        NSUserDefaults.standardUserDefaults().setObject(percentageString, forKey: self.identifier+"_percentage")
        
    }
    
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