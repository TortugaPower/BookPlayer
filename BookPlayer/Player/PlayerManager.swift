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
    static let sharedInstance = PlayerManager()

    var audioPlayer: AVAudioPlayer?
    private var playerItem: AVPlayerItem!
    var fileURL: URL!
    var identifier: String!

    var currentBooks: [Book]!
    var currentBook: Book! {
        return self.currentBooks.first
    }

    private var timer: Timer!

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

            book.chapters = self.playerItem.getChapters()

            //update UI on main thread
            DispatchQueue.main.async(execute: {
                //set book metadata for lockscreen and control center
                var nowPlayingInfo: [String: Any] = [
                    MPMediaItemPropertyTitle: book.title,
                    MPMediaItemPropertyArtist: book.author,
                    MPMediaItemPropertyPlaybackDuration: audioplayer.duration
                ]

                nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(image: book.artwork)

                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

                if book.currentTime > 0.0 {
                    self.jumpTo(book.currentTime)
                }

                //set speed for player
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
        self.jumpBy(30.0)
    }

    func rewind() {
        self.jumpBy(-30.0)
    }

    // MARK: Playback

    func play(_ autoplay: Bool = false) {
        self.playPause()

        update()
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

        update()
    }

    // toggle play/pause of book
    // @TODO: Replace with distinct play() and pause() methods
    func playPause(autoplayed: Bool = false) {
        guard let audioplayer = self.audioPlayer else {
            return
        }

        UserDefaults.standard.set(self.identifier, forKey: UserDefaultsConstants.lastPlayedBook)

        // pause player if it's playing
        if audioplayer.isPlaying {
            self.pause()

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
    }

    func stop() {
        self.audioPlayer?.stop()
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

        guard UserDefaults.standard.bool(forKey: UserDefaultsConstants.autoplayEnabled),
            self.currentBooks.count > 1 else {
            return
        }

        let currentBooks = Array(PlayerManager.sharedInstance.currentBooks.dropFirst())

        load(currentBooks, completion: { (_) in
            let userInfo = ["books": currentBooks]

            NotificationCenter.default.post(name: Notification.Name.AudiobookPlayer.bookChange, object: nil, userInfo: userInfo)
        })
    }
}
