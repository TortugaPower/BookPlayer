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
    var audioPlayer:AVAudioPlayer?
    
    @IBOutlet weak var leftVerticalView: UIView!
    @IBOutlet weak var sliderView: UISlider!
    
    @IBOutlet weak var percentageLabel: UILabel!
    
    @IBOutlet weak var chaptersButton: UIButton!
    @IBOutlet weak var speedButton: UIButton!
    
    
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
    
    //chapters
    var chapterArray:[Chapter] = []
    var currentChapter:Chapter?
    
    //speed
    var currentSpeed:Float = 1.0
    
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
        self.chaptersButton.setTitleColor(UIColor.flatGrayColor(), forState: .Disabled)
        self.speedButton.setTitleColor(UIColor.flatGrayColor(), forState: .Disabled)
        
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
        
        self.percentageLabel.text = ""
        
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
            
            audioplayer.delegate = self
            
            //set smart speed
            let speed = NSUserDefaults.standardUserDefaults().floatForKey(self.identifier+"_speed")
            self.currentSpeed = speed > 0 ? speed : 1.0
            self.speedButton.setTitle("Speed \(String(self.currentSpeed))x", forState: .Normal)
            
            //try loading chapters
            var chapterIndex = 1
            
            let locales = self.playerItem.asset.availableChapterLocales
            for locale in locales {
                let chapters = self.playerItem.asset.chapterMetadataGroupsWithTitleLocale(locale, containingItemsWithCommonKeys: [AVMetadataCommonKeyArtwork])
                
                for chapterMetadata in chapters {
                    
                    let chapter = Chapter(title: AVMetadataItem.metadataItemsFromArray(chapterMetadata.items, withKey: AVMetadataCommonKeyTitle, keySpace: AVMetadataKeySpaceCommon).first?.value?.copyWithZone(nil) as? String ?? "Chapter \(index)",
                                     start: Int(CMTimeGetSeconds(chapterMetadata.timeRange.start)),
                                     duration: Int(CMTimeGetSeconds(chapterMetadata.timeRange.duration)),
                                     index: chapterIndex)

                    if Int(audioplayer.currentTime) >= chapter.start {
                        self.currentChapter = chapter
                    }
                    
                    self.chapterArray.append(chapter)
                    chapterIndex = chapterIndex + 1
                }
                
            }
            
            //set percentage label to stored value
            let currentPercentage = NSUserDefaults.standardUserDefaults().stringForKey(self.identifier+"_percentage") ?? "0%"
            self.percentageLabel.text = currentPercentage
            
            //currentChapter is not reliable because of currentTime is not ready, set to blank
            if self.chapterArray.count > 0 {
                self.percentageLabel.text = ""
            }
            
            
            //update UI on main thread
            dispatch_async(dispatch_get_main_queue(), {
                
                //enable/disable chapters button
                self.chaptersButton.enabled = self.chapterArray.count > 0
                
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
                self.sliderView.value = Float(currentTime)
                self.updateCurrentChapter()
                
                //set speed for player
                audioplayer.enableRate = true
                audioplayer.rate = self.currentSpeed
                
                //play audio automatically
                if let rootVC = self.navigationController?.viewControllers.first as? ListBooksViewController {
                    //only if the book isn't finished
                    if currentTime != maxDuration {
                        rootVC.didPressPlay(self.playButton)
                    }
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
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        //don't do anything special for other segues that weren't identified beforehand
        guard let identifier = segue.identifier else {
            return
        }
        
        //set every modal to preserve current view contaxt
        let vc = segue.destinationViewController
        vc.modalPresentationStyle = .OverCurrentContext
        
        switch identifier {
        case "showChapterSegue":
            let chapterVC = vc as! ChaptersViewController
            chapterVC.chapterArray = self.chapterArray
            chapterVC.currentChapter = self.currentChapter
        case "showSpeedSegue":
            let speedVC = vc as! SpeedViewController
            speedVC.currentSpeed = self.currentSpeed
            break
        default:
            break
        }
    }
    
    @IBAction func didSelectChapter(segue:UIStoryboardSegue){
        
        guard let audioplayer = self.audioPlayer else {
            return
        }
        let vc = segue.sourceViewController as! ChaptersViewController
        audioplayer.currentTime = NSTimeInterval(vc.currentChapter.start)
        
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime
        
        self.updateTimer()
    }
    
    @IBAction func didSelectSpeed(segue:UIStoryboardSegue){
        
        guard let audioplayer = self.audioPlayer else {
            return
        }
        let vc = segue.sourceViewController as! SpeedViewController
        self.currentSpeed = vc.currentSpeed
        
        NSUserDefaults.standardUserDefaults().setFloat(self.currentSpeed, forKey: self.identifier+"_speed")
        self.speedButton.setTitle("Speed \(String(self.currentSpeed))x", forState: .Normal)
        audioplayer.rate = self.currentSpeed
    }
    
    @IBAction func didSelectAction(segue:UIStoryboardSegue){
        
        guard let audioplayer = self.audioPlayer else {
            return
        }
        
        if audioplayer.playing {
            self.playPressed(self.playButton)
        }
        
        let vc = segue.sourceViewController as! MoreViewController
        let action = vc.selectedAction
        
        switch action.rawValue {
        case MoreAction.JumpToStart.rawValue:
            audioplayer.currentTime = 0
            break
        case MoreAction.MarkFinished.rawValue:
            audioplayer.currentTime = audioplayer.duration
            break
        default:
            break
        }
        
        self.updateTimer()
    }
    
    override func prefersStatusBarHidden() -> Bool {
        return true
    }
    
    override func preferredStatusBarUpdateAnimation() -> UIStatusBarAnimation {
        return .Slide
    }
}

extension PlayerViewController: AVAudioPlayerDelegate {
    
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
        
        //if book is completed, reset to start
        if audioplayer.duration == audioplayer.currentTime {
            audioplayer.currentTime = 0
        }
        
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
        
        let percentageString = String(Int(ceil(percentage)))+"%"
        //only update percentage if there are no chapters
        if self.chapterArray.count == 0 {
            self.percentageLabel.text = percentageString
        }
        
        
        //FIXME: this should only be updated when there's change to current percentage
        NSUserDefaults.standardUserDefaults().setObject(percentageString, forKey: self.identifier+"_percentage")
        
        //update chapter
        self.updateCurrentChapter()
        
        //stop timer if the book is finished
        if Int(audioplayer.currentTime) == Int(audioplayer.duration) {
            if self.timer.valid {
                self.timer.invalidate()
            }
            
            self.playButton.setImage(self.playImage, forState: .Normal)
            return
        }
    }
    
    func updateCurrentChapter() {
        guard let audioplayer = self.audioPlayer else {
            return
        }
        
        for chapter in self.chapterArray {
            if Int(audioplayer.currentTime) >= chapter.start {
                self.currentChapter = chapter
                self.percentageLabel.text = "Chapter \(chapter.index) of \(self.chapterArray.count)"
                
            }
        }
    }
    
    //leave the slider at max
    func audioPlayerDidFinishPlaying(player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            player.currentTime = player.duration
            self.updateTimer()
        }
    }
    
}