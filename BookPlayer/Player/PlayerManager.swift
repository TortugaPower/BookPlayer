//
//  PlayerManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/31/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import Foundation
import AVFoundation
import MediaPlayer

class PlayerManager: NSObject {
    static let shared = PlayerManager()

    var audioPlayer: AVAudioPlayer?
    private var playerItem: AVPlayerItem!
    var fileURL: URL!
    var identifier: String!

    lazy var currentBooks = [Book]()
    var currentBook: Book! {
        return self.currentBooks.first
    }

    private var timer: Timer!

    func load(_ books: [Book], completion:@escaping (AVAudioPlayer?) -> Void) {
        if let player = self.audioPlayer,
            self.currentBooks.count == books.count { // @TODO : fix logic
                player.stop()
                // notify?
        }

        self.currentBooks = books

        let book = books.first!

        self.playerItem = DataManager.playerItem(from: book)
        self.fileURL = book.fileURL
        self.identifier = book.identifier

        //notify book is loading
        let userInfo = ["book": book]
        NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.loadingBook, object: nil, userInfo: userInfo)

        // load data on background thread
        DispatchQueue.global().async {
            // try loading the player
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: book.fileURL)
            } catch {
                NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.errorLoadingBook, object: nil)
                completion(nil)
                return
            }

            guard let audioplayer = self.audioPlayer else {
                //notify error
                NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.errorLoadingBook, object: nil)
                completion(nil)
                return
            }

            audioplayer.delegate = self
            audioplayer.enableRate = true

            if UserDefaults.standard.bool(forKey: UserDefaultsConstants.boostVolumeEnabled) {
                audioplayer.volume = 2.0
            }

            //update UI on main thread
            DispatchQueue.main.async(execute: {
                //set book metadata for lockscreen and control center
                var nowPlayingInfo: [String: Any] = [
                    MPMediaItemPropertyTitle: book.title,
                    MPMediaItemPropertyArtist: book.author,
                    MPMediaItemPropertyPlaybackDuration: audioplayer.duration
                ]

                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
                    boundsSize: book.artwork.size,
                    requestHandler: { (_) -> UIImage in
                        return book.artwork
                    }
                )

                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

                if book.currentTime > 0.0 {
                    self.jumpTo(book.currentTime)
                }

                // Set speed for player
                audioplayer.rate = self.speed

                NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.bookReady, object: nil)

                completion(audioplayer)
            })
        }
    }

    // called every second by the timer
    @objc func update() {
        guard let audioplayer = self.audioPlayer else {
            return
        }

        self.currentBook.currentTime = audioplayer.currentTime

        let isPercentageDifferent = self.currentBook.percentage != self.currentBook.percentCompleted

        self.currentBook.percentCompleted = self.currentBook.percentage

        DataManager.saveContext()

        // Notify
        if isPercentageDifferent {
            NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.updatePercentage, object: nil, userInfo: [
                "percentCompletedString": self.currentBook.percentCompletedRoundedString,
                "fileURL": self.fileURL
            ] as [String: Any])
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime

        // stop timer if the book is finished
        if Int(audioplayer.currentTime) == Int(audioplayer.duration) {
            if self.timer != nil && self.timer.isValid {
                self.timer.invalidate()
            }

            // Once book a book is finished, ask for a review
            UserDefaults.standard.set(true, forKey: "ask_review")
            NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.bookEnd, object: nil)
        }

        let userInfo = [
            "time": currentTime,
            "fileURL": self.currentBooks.first!.fileURL
            ] as [String: Any]

        // notify
        NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.bookPlaying, object: nil, userInfo: userInfo)
    }

    // MARK: Player states

    var isLoaded: Bool {
        return self.audioPlayer != nil
    }

    var isPlaying: Bool {
        return audioPlayer?.isPlaying ?? false
    }

    var duration: TimeInterval {
        return audioPlayer?.duration ?? 0.0
    }

    var currentTime: TimeInterval {
        get {
            return audioPlayer?.currentTime ?? 0.0
        }

        set {
            guard let player = self.audioPlayer else {
                return
            }

            player.currentTime = newValue

            self.currentBook.currentTime = newValue
        }
    }

    var speed: Float {
        get {
            let useGlobalSpeed = UserDefaults.standard.bool(forKey: UserDefaultsConstants.globalSpeedEnabled)
            let globalSpeed = UserDefaults.standard.float(forKey: "global_speed")
            let localSpeed = UserDefaults.standard.float(forKey: self.identifier+"_speed")
            let speed = useGlobalSpeed ? globalSpeed : localSpeed

            return speed > 0 ? speed : 1.0
        }

        set {
            guard let audioPlayer = self.audioPlayer else {
                return
            }

            UserDefaults.standard.set(newValue, forKey: self.identifier+"_speed")

            // set global speed
            if UserDefaults.standard.bool(forKey: UserDefaultsConstants.globalSpeedEnabled) {
                UserDefaults.standard.set(newValue, forKey: "global_speed")
            }

            audioPlayer.rate = newValue
        }
    }

    var rewindInterval: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: UserDefaultsConstants.rewindInterval) == nil {
                return 30.0
            }

            return UserDefaults.standard.double(forKey: UserDefaultsConstants.rewindInterval)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsConstants.rewindInterval)

            MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [newValue] as [NSNumber]
        }
    }

    var forwardInterval: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: UserDefaultsConstants.forwardInterval) == nil {
                return 30.0
            }

            return UserDefaults.standard.double(forKey: UserDefaultsConstants.forwardInterval)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaultsConstants.forwardInterval)

            MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [newValue] as [NSNumber]
        }
    }

    // MARK: Seek Controls

    func jumpTo(_ time: Double, fromEnd: Bool = false) {
        guard let player = self.audioPlayer else {
            return
        }

        player.currentTime = fromEnd ? player.duration - time : time

        update()
    }

    func jumpBy(_ direction: Double) {
        guard let player = self.audioPlayer else {
            return
        }

        player.currentTime += direction

        update()
    }

    func forward() {
        self.jumpBy(self.forwardInterval)
    }

    func rewind() {
        self.jumpBy(-self.rewindInterval)
    }

    // MARK: Playback

    func play(_ autoplayed: Bool = false) {
        guard let audioplayer = self.audioPlayer else {
            return
        }

        UserDefaults.standard.set(self.identifier, forKey: UserDefaultsConstants.lastPlayedBook)

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
            audioplayer.currentTime = 0.0
        }

        // create timer if needed
        if self.timer == nil || (self.timer != nil && !self.timer.isValid) {
            self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(update), userInfo: nil, repeats: true)

            RunLoop.main.add(self.timer, forMode: RunLoopMode.commonModes)
        }

        // set play state on player and control center
        audioplayer.play()

        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.bookPlayed, object: nil)
        }

        self.update()
    }

    func pause() {
        guard let audioplayer = self.audioPlayer else {
            return
        }

        UserDefaults.standard.set(self.identifier, forKey: UserDefaultsConstants.lastPlayedBook)

        // invalidate timer if needed
        if self.timer != nil {
            self.timer.invalidate()
        }

        // set pause state on player and control center
        audioplayer.stop()

        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo![MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime

        UserDefaults.standard.set(Date(), forKey: UserDefaultsConstants.lastPauseTime+"_\(self.identifier)")

        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            // @TODO: Handle error if AVAudioSession fails to become active again
        }

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.bookPaused, object: nil)
        }

        self.update()
    }

    // toggle play/pause of book
    // @TODO: Replace with distinct play() and pause() methods
    func playPause(autoplayed: Bool = false) {
        guard let audioplayer = self.audioPlayer else {
            return
        }

        // pause player if it's playing
        if audioplayer.isPlaying {
            self.pause()
        } else {
            self.play()
        }
    }

    func stop() {
        self.audioPlayer?.stop()

        // TODO: This should also dimiss the mini player / send a notification that the current book was stoppped
    }
}

extension PlayerManager: AVAudioPlayerDelegate {
    // leave the slider at max
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else {
            return
        }

        player.currentTime = player.duration

        self.update()

        let currentBooks = Array(PlayerManager.shared.currentBooks.dropFirst())

        guard !currentBooks.isEmpty else {
            return
        }

        load(currentBooks, completion: { (_) in
            let userInfo = ["books": currentBooks]

            NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.bookChange, object: nil, userInfo: userInfo)
        })
    }
}
