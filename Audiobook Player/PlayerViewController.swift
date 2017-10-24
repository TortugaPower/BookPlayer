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
import StoreKit

class PlayerViewController: UIViewController {
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    
    @IBOutlet weak var playButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var rewindButton: UIButton!
    
    @IBOutlet weak var maxTimeLabel: UILabel!
    @IBOutlet weak var currentTimeLabel: UILabel!
    
    @IBOutlet weak var timeSeparator: UILabel!
    
    @IBOutlet weak var leftVerticalView: UIView!
    @IBOutlet weak var sliderView: UISlider!
    
    @IBOutlet weak var percentageLabel: UILabel!
    
    @IBOutlet weak var chaptersButton: UIButton!
    @IBOutlet weak var speedButton: UIButton!
    @IBOutlet weak var sleepButton: UIButton!
    
    @IBOutlet weak var sleepTimerWidthConstraint: NSLayoutConstraint!
    
    //keep in memory images to toggle play/pause
    let playImage = UIImage(named: "playButton")
    let pauseImage = UIImage(named: "pauseButton")
    
    var currentBook: Book!
    
    //timer to update sleep time
    var sleepTimer:Timer!
    
    //MARK: Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //set UI colors
        let colors:[UIColor] = [
            UIColor.flatGrayColorDark(),
            UIColor.flatSkyBlueColorDark()
        ]
        self.view.backgroundColor = GradientColor(.radial, frame: view.frame, colors: colors)
        self.leftVerticalView.backgroundColor = UIColor.flatRed()
        self.maxTimeLabel.textColor = UIColor.flatWhiteColorDark()
        self.authorLabel.textColor = UIColor.flatWhiteColorDark()
        self.timeSeparator.textColor = UIColor.flatWhiteColorDark()
        self.chaptersButton.setTitleColor(UIColor.flatGray(), for: .disabled)
        self.speedButton.setTitleColor(UIColor.flatGray(), for: .disabled)
        self.sleepButton.tintColor = UIColor.white
        
        modalPresentationCapturesStatusBarAppearance = true
        
        self.setStatusBarStyle(UIStatusBarStyleContrast)
        
        //register for appDelegate requestReview notifications
        NotificationCenter.default.addObserver(self, selector: #selector(self.requestReview), name: Notification.Name.AudiobookPlayer.requestReview, object: nil)
        //register for timer update
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateTimer(_:)), name: Notification.Name.AudiobookPlayer.updateTimer, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updatePercentage(_:)), name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.updateCurrentChapter(_:)), name: Notification.Name.AudiobookPlayer.updateChapter, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookReady), name: Notification.Name.AudiobookPlayer.bookReady, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.bookEnd), name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)

        //set initial state for slider
        self.sliderView.setThumbImage(UIImage(), for: UIControlState())
        self.sliderView.tintColor = UIColor.flatLimeColorDark()
        self.sliderView.maximumValue = 100
        self.sliderView.value = 0
        
        self.titleLabel.text = self.currentBook.title
        self.authorLabel.text = self.currentBook.author
        
        //set percentage label to stored value
        let currentPercentage = UserDefaults.standard.string(forKey: self.currentBook.identifier+"_percentage") ?? "0%"
        self.percentageLabel.text = currentPercentage
        
        //get stored value for current time of book
        let currentTime = UserDefaults.standard.integer(forKey: self.currentBook.identifier)
        
        //update UI if needed and set player to stored time
        if currentTime > 0 {
            let formattedCurrentTime = self.formatTime(currentTime)
            self.currentTimeLabel.text = formattedCurrentTime
            self.sliderView.value = Float(currentTime)
        }
        
        //update max duration label of book
        let maxDuration = self.currentBook.duration
        self.maxTimeLabel.text = self.formatTime(maxDuration)
        
        //make sure player is for a different book
        guard PlayerManager.sharedInstance.fileURL != self.currentBook.fileURL else {
            if PlayerManager.sharedInstance.isPlaying() {
                self.playButton.setImage(self.pauseImage, for: UIControlState())
            } else {
                self.playButton.setImage(self.playImage, for: UIControlState())
            }
            
            //set smart speed
            self.speedButton.setTitle("Speed \(String(PlayerManager.sharedInstance.currentSpeed))x", for: UIControlState())
            
            //enable/disable chapters button
            self.chaptersButton.isEnabled = !PlayerManager.sharedInstance.chapterArray.isEmpty
            return
        }
        
        MBProgressHUD.showAdded(to: self.view, animated: true)
        //replace player with new one
        PlayerManager.sharedInstance.load(self.currentBook) { (audioPlayer) in
            //currentChapter is not reliable because of currentTime is not ready, set to blank
            if !PlayerManager.sharedInstance.chapterArray.isEmpty {
                self.percentageLabel.text = ""
            }
            
            //set smart speed
            self.speedButton.setTitle("Speed \(String(PlayerManager.sharedInstance.currentSpeed))x", for: UIControlState())
            
            //enable/disable chapters button
            self.chaptersButton.isEnabled = !PlayerManager.sharedInstance.chapterArray.isEmpty
        }
    }
    
    //Resize sleep button on orientation transition
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { (context) in
            let orientation = UIApplication.shared.statusBarOrientation
            
            if orientation.isLandscape {
                self.sleepTimerWidthConstraint.constant = 20
            } else {
                self.sleepTimerWidthConstraint.constant = 30
            }
            
        })
    }
    
    @IBAction func presentMore(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "MoreViewController") as! MoreViewController
        
        self.presentModal(vc, animated: true, completion: nil)
    }
    
    @IBAction func presentChapter(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "ChaptersViewController") as! ChaptersViewController
        
        self.presentModal(vc, animated: true, completion: nil)
    }
    
    @IBAction func presentSpeed(_ sender: UIButton) {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SpeedViewController") as! SpeedViewController
        
        self.presentModal(vc, animated: true, completion: nil)
    }
    
    
    @IBAction func didSelectChapter(_ segue:UIStoryboardSegue){
        
        guard PlayerManager.sharedInstance.isLoaded() else {
            return
        }
        
        let vc = segue.source as! ChaptersViewController
        let chapter = vc.currentChapter!
        
        PlayerManager.sharedInstance.setChapter(chapter)
    }
    
    @IBAction func didSelectSpeed(_ segue:UIStoryboardSegue){
        
        guard PlayerManager.sharedInstance.isLoaded() else {
            return
        }
        
        let vc = segue.source as! SpeedViewController
        let speed = vc.currentSpeed!
        
        PlayerManager.sharedInstance.setSpeed(speed)
        self.speedButton.setTitle("Speed \(String(PlayerManager.sharedInstance.currentSpeed))x", for: UIControlState())
    }
    
    @IBAction func didSelectAction(_ segue:UIStoryboardSegue){
        
        guard PlayerManager.sharedInstance.isLoaded() else {
            return
        }
        
        PlayerManager.sharedInstance.stop()

        let vc = segue.source as! MoreViewController
        guard let action = vc.selectedAction else {
            return
        }
        
        switch action.rawValue {
        case MoreAction.jumpToStart.rawValue:
            
            PlayerManager.sharedInstance.setTime(0.0)
            break
        case MoreAction.markFinished.rawValue:
            PlayerManager.sharedInstance.setTime(PlayerManager.sharedInstance.audioPlayer?.duration ?? 0.0)
            break
        default:
            break
        }
        let test = Notification(name: Notification.Name.AudiobookPlayer.openURL)
        self.updateTimer(test)
    }
    
    @IBAction func didPressSleepTimer(_ sender: UIButton) {
        
        var alertTitle:String? = nil
        if self.sleepTimer != nil && self.sleepTimer.isValid {
            alertTitle = " "
        }
        
        let alert = UIAlertController(title: alertTitle, message: nil, preferredStyle: .actionSheet)
        
        
        alert.addAction(UIAlertAction(title: "Off", style: .default, handler: { action in
            self.sleep(in: nil)
        }))
        
        alert.addAction(UIAlertAction(title: "In 5 Minutes", style: .default, handler: { action in
            self.sleep(in: 300)
        }))
        
        alert.addAction(UIAlertAction(title: "In 10 Minutes", style: .default, handler: { action in
            self.sleep(in: 600)
        }))
        alert.addAction(UIAlertAction(title: "In 15 Minutes", style: .default, handler: { action in
            self.sleep(in: 900)
        }))
        alert.addAction(UIAlertAction(title: "In 30 Minutes", style: .default, handler: { action in
            self.sleep(in: 1800)
        }))
        alert.addAction(UIAlertAction(title: "In 45 Minutes", style: .default, handler: { action in
            self.sleep(in: 2700)
        }))
        alert.addAction(UIAlertAction(title: "In One Hour", style: .default, handler: { action in
            self.sleep(in: 3600)
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        alert.popoverPresentationController?.sourceView = self.view
        alert.popoverPresentationController?.sourceRect = CGRect(x: Double(self.view.bounds.size.width / 2.0), y: Double(self.view.bounds.size.height-45), width: 1.0, height: 1.0)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    func sleep(in seconds:Int?) {
        UserDefaults.standard.set(seconds, forKey: "sleep_timer")
        
        guard seconds != nil else {
            self.sleepButton.tintColor = UIColor.white
            //kill timer
            if self.sleepTimer != nil {
                self.sleepTimer.invalidate()
            }
            return
        }
        
        self.sleepButton.tintColor = UIColor.flatLimeColorDark()
        
        //create timer if needed
        if self.sleepTimer == nil || (self.sleepTimer != nil && !self.sleepTimer.isValid) {
            self.sleepTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateSleepTimer), userInfo: nil, repeats: true)
            RunLoop.main.add(self.sleepTimer, forMode: RunLoopMode.commonModes)
        }
    }
    
    func updateSleepTimer(){
        
        guard PlayerManager.sharedInstance.isLoaded() else {
            //kill timer
            if self.sleepTimer != nil {
                self.sleepTimer.invalidate()
            }
            return
        }
        
        let currentTime = UserDefaults.standard.integer(forKey: "sleep_timer")
        
        var newTime:Int? = currentTime - 1
        
        if let alertVC = self.presentedViewController, alertVC is UIAlertController {
            alertVC.title = "Time: " + self.formatTime(newTime!)
        }
        
        if newTime! <= 0 {
            newTime = nil
            //stop audiobook
            if self.sleepTimer != nil && self.sleepTimer.isValid {
                self.sleepTimer.invalidate()
            }
            
            if PlayerManager.sharedInstance.isPlaying() {
                self.playPressed(self.playButton)
            }
        }
        UserDefaults.standard.set(newTime , forKey: "sleep_timer")
    }
    
    override var preferredStatusBarUpdateAnimation : UIStatusBarAnimation {
        return .slide
    }
}

extension PlayerViewController: AVAudioPlayerDelegate {
    
    //skip time forward
    @IBAction func forwardPressed(_ sender: UIButton) {
        PlayerManager.sharedInstance.forwardPressed()
    }
    
    //skip time backwards
    @IBAction func rewindPressed(_ sender: UIButton) {
        PlayerManager.sharedInstance.rewindPressed()
    }
    
    //toggle play/pause of book
    @IBAction func playPressed(_ sender: UIButton) {
        if PlayerManager.sharedInstance.isPlaying() {
            self.playButton.setImage(self.playImage, for: UIControlState())
        } else {
            self.playButton.setImage(self.pauseImage, for: UIControlState())
        }
        
        PlayerManager.sharedInstance.playPressed()
    }
    
    //timer callback (called every second)
    func updateTimer(_ notification:Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            let timeText = userInfo["timeString"] as? String,
            let percentage = userInfo["percentage"] as? Float,
            fileURL == self.currentBook.fileURL else {
            return
        }
        
        //update current time label
        self.currentTimeLabel.text = timeText
        
        //update book read percentage
        self.sliderView.value = percentage
    }
    
    //percentage callback
    func updatePercentage(_ notification:Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            fileURL == self.currentBook.fileURL,
            let percentageString = userInfo["percentageString"] as? String,
            let hasChapters = userInfo["hasChapters"] as? Bool,
            !hasChapters else {
                return
        }
        
        self.percentageLabel.text = percentageString
    }
    
    func requestReview(){
        //don't do anything if flag isn't true
        guard UserDefaults.standard.bool(forKey: "ask_review") else {
            return
        }
        
        // request for review
        if #available(iOS 10.3, *),
            UIApplication.shared.applicationState == .active {
            SKStoreReviewController.requestReview()
            UserDefaults.standard.set(false, forKey: "ask_review")
        }
    }
    
    func bookReady(){
        MBProgressHUD.hideAllHUDs(for: self.view, animated: true)
        
        if PlayerManager.sharedInstance.isPlaying() {
            self.playButton.setImage(self.playImage, for: UIControlState())
        } else {
            self.playButton.setImage(self.pauseImage, for: UIControlState())
        }
        
        PlayerManager.sharedInstance.playPressed()
    }
    
    func bookEnd() {
        self.playButton.setImage(self.playImage, for: UIControlState())
        self.requestReview()
    }
    
    func updateCurrentChapter(_ notification:Notification) {
        guard let userInfo = notification.userInfo,
            let fileURL = userInfo["fileURL"] as? URL,
            let chapterString = userInfo["chapterString"] as? String,
            fileURL == self.currentBook.fileURL else {
                return
        }
        
        self.percentageLabel.text = chapterString
    }
}
