//
//  PlayerManager.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 5/31/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

class PlayerManager: NSObject {
    static let shared = PlayerManager()

    let defaults: UserDefaults = UserDefaults.standard

    // current item to play
    var playerItem: AVPlayerItem!
    var currentBooks: [Book]!

    var fileURL: URL!
    var audioPlayer: AVAudioPlayer?

    // @TODO: Refactor. Chapters should be stored on the book
    var chapterArray: [Chapter] = []
    var currentChapter: Chapter?

    // book identifier for `NSUserDefaults`
    var identifier: String!

    // speed
    var currentSpeed: Float {
        guard let player = self.audioPlayer else {
            return 1.0
        }

        return player.rate
    }

    // timer to update labels about time
    var timer: Timer!

    let center = NotificationCenter.default

    var isLoaded: Bool {
        return self.audioPlayer != nil
    }

    var isPlaying: Bool {
        guard let audioPlayer = self.audioPlayer else {
            return false
        }

        return audioPlayer.isPlaying
    }

    func play() {
        guard let audioPlayer = self.audioPlayer else {
            return
        }

        audioPlayer.play()
    }

    func stop() {
        guard let audioPlayer = self.audioPlayer else {
            return
        }

        audioPlayer.stop()
    }

    func load(_ books: [Book], completion:@escaping (AVAudioPlayer?) -> Void) {
        if let player = self.audioPlayer,
            let currentBooks = self.currentBooks,
            currentBooks.count == books.count { // @TODO : fix logic
                player.stop()
                // notify?
        }

        self.currentBooks = books

        let book = books.first!

        self.playerItem = AVPlayerItem(asset: book.asset)
        self.fileURL = book.fileURL
        self.identifier = book.identifier
        self.currentChapter = nil

        // load data on background thread
        DispatchQueue.global().async {
            let mediaArtwork = MPMediaItemArtwork(image: book.artwork)

            // try loading the player
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: book.fileURL)
            } catch {
                self.center.post(name: Notification.Name.AudiobookPlayer.errorLoadingBook, object: nil)

                completion(nil)

                return
            }

            guard let audioplayer = self.audioPlayer else {
                //notify error
                self.center.post(name: Notification.Name.AudiobookPlayer.errorLoadingBook, object: nil)

                completion(nil)

                return
            }

            audioplayer.delegate = self
            audioplayer.enableRate = true

            if self.defaults.bool(forKey: UserDefaultsConstants.boostVolumeEnabled) {
                audioplayer.volume = 2.0
            }

            // @TODO: Remove
            self.chapterArray = book.loadChapters()

            // Update UI on main thread
            DispatchQueue.main.async(execute: {
                // Set book metadata for lockscreen and control center
                MPNowPlayingInfoCenter.default().nowPlayingInfo = [
                    MPMediaItemPropertyTitle: book.title,
                    MPMediaItemPropertyArtist: book.author,
                    MPMediaItemPropertyPlaybackDuration: audioplayer.duration,
                    MPMediaItemPropertyArtwork: mediaArtwork
                ]

                let currentTime = self.getStoredTime()

                //update UI if needed and set player to stored time
                if currentTime > 0 {
                    audioplayer.currentTime = TimeInterval(currentTime)
                }

                // Notify
                self.updateCurrentChapter()

                // Set speed for player
                audioplayer.rate = self.getSpeed()

                self.center.post(name: Notification.Name.AudiobookPlayer.bookReady, object: nil)

                completion(audioplayer)
            })
        }
    }

    func getStoredTime() -> Int {
        // get stored value for current time of book in seconds
        var lastPlayedPositionInSeconds = self.defaults.integer(forKey: self.identifier)

        // If smartRewind is enabled and time since last play was 10 minutes (599s), rewind audiobook by 30 seconds or to start.
        if let lastPlayTime: Date = self.defaults.object(forKey: UserDefaultsConstants.lastPauseTime+"_\(self.identifier)") as? Date, self.defaults.bool(forKey: UserDefaultsConstants.smartRewindEnabled) {
            if Date().timeIntervalSince(lastPlayTime) > 599 {
                lastPlayedPositionInSeconds = max(lastPlayedPositionInSeconds - 30, 0)
                self.defaults.set(nil, forKey: UserDefaultsConstants.lastPauseTime+"_\(self.identifier)")
            }
        }

        return lastPlayedPositionInSeconds
    }

    func getSpeed() -> Float {
        let speed = self.defaults.bool(forKey: UserDefaultsConstants.globalSpeedEnabled) ? self.defaults.float(forKey: "global_speed") : self.defaults.float(forKey: self.identifier+"_speed")

        return speed > 0 ? speed : 1.0
    }

    // move to chapter
    func setChapter(_ chapter: Chapter) {
        guard let audioPlayer = self.audioPlayer else {
            return
        }

        audioPlayer.currentTime = TimeInterval(chapter.start)

        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioPlayer.currentTime

        self.updateTimer()
    }

    // set speed
    func setSpeed(_ speed: Float) {
        guard let audioPlayer = self.audioPlayer else {
            return
        }

        defaults.set(speed, forKey: self.identifier+"_speed")

        //set global speed
        if self.defaults.bool(forKey: UserDefaultsConstants.globalSpeedEnabled) == true {
            self.defaults.set(speed, forKey: "global_speed")
        }

        audioPlayer.rate = speed
    }

    // set speed
    func setTime(_ time: TimeInterval) {
        guard let audioPlayer = self.audioPlayer else {
            return
        }

        audioPlayer.currentTime = time

        self.updateTimer()
    }

    // skip time forward
    func forward() {
        guard let audioplayer = self.audioPlayer else {
            return
        }

        audioplayer.currentTime += 30

        self.updateTimer()
    }

    // skip time backwards
    func rewind() {
        guard let audioplayer = self.audioPlayer else {
            return
        }

        audioplayer.currentTime -= 30

        self.updateTimer()
    }

    // toggle play/pause of book
    func playPause(autoplayed: Bool = false) {
        guard let audioplayer = self.audioPlayer else {
            return
        }

        defaults.set(self.identifier, forKey: UserDefaultsConstants.lastPlayedBook)

        // pause player if it's playing
        if audioplayer.isPlaying {
            // invalidate timer if needed
            if self.timer != nil {
                self.timer.invalidate()
            }

            // set pause state on player and control center
            audioplayer.stop()
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0
            MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime

            defaults.set(Date(), forKey: UserDefaultsConstants.lastPauseTime+"_\(self.identifier)")

            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                // @TODO: Handle error if AVAudioSession fails to become active again
            }

            DispatchQueue.main.async {
                self.center.post(name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
            }

            return
        }

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // @TODO: Handle error if AVAudioSession fails to become active again
        }

        let completed = Int(audioplayer.duration) == Int(audioplayer.currentTime)

        if autoplayed && completed {
            return
        }

        // if book is completed, reset to start
        if completed {
            audioplayer.currentTime = 0
        }

        // create timer if needed
        if self.timer == nil || (self.timer != nil && !self.timer.isValid) {
            self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
            RunLoop.main.add(self.timer, forMode: RunLoopMode.commonModes)
        }

        // set play state on player and control center
        audioplayer.play()

        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1
        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime

        DispatchQueue.main.async {
            self.center.post(name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        }
    }

    // timer callback (called every second)
    @objc func updateTimer() {
        guard let audioplayer = self.audioPlayer else {
            return
        }

        // Notify controls
        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime

        let currentTime = Int(audioplayer.currentTime)

        // store state every 2 seconds, I/O can be expensive
        if currentTime % 2 == 0 {
            defaults.set(currentTime, forKey: self.identifier)
        }

        let storedPercentage = defaults.string(forKey: self.identifier+"_percentage") ?? "0%"

        // calculate book read percentage based on current time
        let percentage = (Float(currentTime) / Float(audioplayer.duration)) * 100
        let percentageString = String(Int(ceil(percentage)))+"%"

        let userInfo = [
            "time": currentTime,
            "percentage": percentage,
            "percentageString": percentageString,
            "hasChapters": self.currentBooks.first!.hasChapters,
            "fileURL": self.currentBooks.first!.fileURL
            ] as [String: Any]

        // notify percentage
        if storedPercentage != percentageString {
            defaults.set(percentageString, forKey: self.identifier+"_percentage")

            self.center.post(name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil, userInfo: userInfo)
        }

        // update chapter
        self.updateCurrentChapter()

        // stop timer if the book is finished
        if Int(audioplayer.currentTime) == Int(audioplayer.duration) {
            if self.timer != nil && self.timer.isValid {
                self.timer.invalidate()
            }

            // Once book a book is finished, ask for a review
            defaults.set(true, forKey: "ask_review")

            self.center.post(name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
        }

        // notify
        self.center.post(name: Notification.Name.AudiobookPlayer.updateTimer, object: nil, userInfo: userInfo)
        self.center.post(name: Notification.Name.AudiobookPlayer.updateTimer, object: nil, userInfo: userInfo)
    }

    func updateCurrentChapter() {
        guard let audioplayer = self.audioPlayer else {
            return
        }

        // @TODO: a book should report its current chapter just by updating its play position
        for chapter in self.chapterArray {
            if Int(audioplayer.currentTime) >= chapter.start {
                self.currentChapter = chapter

                let chapterString = "Chapter \(chapter.index) of \(self.chapterArray.count)"
                let userInfo = [
                    "chapterString": chapterString,
                    "fileURL": self.currentBooks.first!.fileURL
                    ] as [String: Any]

                // notify
                self.center.post(name: Notification.Name.AudiobookPlayer.updateChapter, object: nil, userInfo: userInfo)
            }
        }
    }
}

extension PlayerManager: AVAudioPlayerDelegate {
    // leave the slider at max
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else {
            return
        }

        player.currentTime = player.duration

        self.updateTimer()

        guard UserDefaults.standard.bool(forKey: UserDefaultsConstants.autoplayEnabled), self.currentBooks.count > 1 else {
            return
        }

        let currentBooks = Array(PlayerManager.shared.currentBooks.dropFirst())

        load(currentBooks, completion: { (_) in
            let userInfo = ["books": currentBooks]

            self.center.post(name: Notification.Name.AudiobookPlayer.bookChange, object: nil, userInfo: userInfo)
        })
    }
}
