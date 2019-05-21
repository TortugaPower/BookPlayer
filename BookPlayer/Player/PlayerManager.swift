//
//  PlayerManager.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/31/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import AVFoundation
import Foundation
import MediaPlayer

// swiftlint:disable file_length

class PlayerManager: NSObject {
    static let shared = PlayerManager()

    static let speedOptions: [Float] = [2.5, 2, 1.75, 1.5, 1.25, 1, 0.75]

    private var audioPlayer: AVAudioPlayer?

    var currentBook: Book?

    private var nowPlayingInfo = [String: Any]()

    private var timer: Timer!

    private let queue = OperationQueue()

    var outputPort: AVAudioSessionPortDescription?

    private(set) var hasLoadedBook = false

    func load(_ book: Book, completion: @escaping (Bool) -> Void) {
        if self.currentBook != nil {
            self.stop()
        }

        self.currentBook = book

        self.queue.addOperation {
            // try loading the player
            guard let fileURL = book.fileURL,
                let audioplayer = try? AVAudioPlayer(contentsOf: fileURL) else {
                DispatchQueue.main.async(execute: {
                    self.currentBook = nil

                    completion(false)
                })

                return
            }

            self.audioPlayer = audioplayer

            audioplayer.delegate = self
            audioplayer.enableRate = true

            self.boostVolume = UserDefaults.standard.bool(forKey: Constants.UserDefaults.boostVolumeEnabled.rawValue)

            // Update UI on main thread
            DispatchQueue.main.async(execute: {
                // Set book metadata for lockscreen and control center
                self.nowPlayingInfo = [
                    MPMediaItemPropertyTitle: book.title as Any,
                    MPMediaItemPropertyArtist: book.author as Any,
                    MPMediaItemPropertyPlaybackDuration: audioplayer.duration,
                    MPNowPlayingInfoPropertyDefaultPlaybackRate: self.speed,
                    MPNowPlayingInfoPropertyPlaybackProgress: audioplayer.currentTime / audioplayer.duration
                ]

                self.nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: book.artwork.size,
                                                                                     requestHandler: { (_) -> UIImage in
                                                                                         book.artwork
                })

                MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo

                if book.currentTime > 0.0 {
                    self.jumpTo(book.currentTime)
                }

                // Set speed for player
                audioplayer.rate = self.speed

                NotificationCenter.default.post(name: .bookReady, object: nil, userInfo: ["book": book])

                completion(true)
                self.hasLoadedBook = true
            })
        }
    }

    // Called every second by the timer
    @objc func update() {
        guard let audioplayer = self.audioPlayer,
            let book = self.currentBook,
            let fileURL = book.fileURL else {
            return
        }

        book.currentTime = audioplayer.currentTime

        let isPercentageDifferent = book.percentage != book.percentCompleted || (book.percentCompleted == 0 && book.progress > 0)

        book.percentCompleted = book.percentage

        DataManager.saveContext()
        UserActivityManager.shared.recordTime()

        // Notify
        if isPercentageDifferent {
            NotificationCenter.default.post(name: .updatePercentage,
                                            object: nil,
                                            userInfo: [
                                                "progress": book.progress,
                                                "fileURL": fileURL
            ] as [String: Any])
        }

        self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime

        MPNowPlayingInfoCenter.default().nowPlayingInfo = self.nowPlayingInfo

        // stop timer if the book is finished
        if Int(audioplayer.currentTime) == Int(audioplayer.duration) {
            if self.timer != nil, self.timer.isValid {
                self.timer.invalidate()
            }

            // Once book a book is finished, ask for a review
            UserDefaults.standard.set(true, forKey: "ask_review")
            self.markAsCompleted(true)
        }

        if let currentChapter = book.currentChapter,
            book.currentTime > currentChapter.end || book.currentTime < currentChapter.start {
            book.updateCurrentChapter()
            NotificationCenter.default.post(name: .chapterChange, object: nil, userInfo: nil)
        }

        let userInfo = [
            "time": currentTime,
            "fileURL": fileURL
        ] as [String: Any]

        // Notify
        NotificationCenter.default.post(name: .bookPlaying, object: nil, userInfo: userInfo)
    }

    // MARK: - Player states

    var isLoaded: Bool {
        return self.audioPlayer != nil
    }

    var isPlaying: Bool {
        return self.audioPlayer?.isPlaying ?? false
    }

    var boostVolume: Bool = false {
        didSet {
            self.audioPlayer?.volume = self.boostVolume
                ? Constants.Volume.boosted.rawValue
                : Constants.Volume.normal.rawValue
        }
    }

    var duration: TimeInterval {
        return self.audioPlayer?.duration ?? 0.0
    }

    var currentTime: TimeInterval {
        get {
            return self.audioPlayer?.currentTime ?? 0.0
        }

        set {
            guard let player = self.audioPlayer else { return }

            player.currentTime = newValue
        }
    }

    var speed: Float {
        get {
            guard let currentBook = self.currentBook else {
                return 1.0
            }

            let useGlobalSpeed = UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue)
            let globalSpeed = UserDefaults.standard.float(forKey: "global_speed")
            let localSpeed = currentBook.playlist?.speed ?? currentBook.speed
            let speed = useGlobalSpeed ? globalSpeed : localSpeed

            return speed > 0 ? speed : 1.0
        }

        set {
            guard let audioPlayer = self.audioPlayer, let currentBook = self.currentBook else {
                return
            }

            currentBook.playlist?.speed = newValue
            currentBook.speed = newValue
            DataManager.saveContext()

            // set global speed
            if UserDefaults.standard.bool(forKey: Constants.UserDefaults.globalSpeedEnabled.rawValue) {
                UserDefaults.standard.set(newValue, forKey: "global_speed")
            }

            audioPlayer.rate = newValue
        }
    }

    var rewindInterval: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: Constants.UserDefaults.rewindInterval.rawValue) == nil {
                return 30.0
            }

            return UserDefaults.standard.double(forKey: Constants.UserDefaults.rewindInterval.rawValue)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.rewindInterval.rawValue)

            MPRemoteCommandCenter.shared().skipBackwardCommand.preferredIntervals = [newValue] as [NSNumber]
        }
    }

    var forwardInterval: TimeInterval {
        get {
            if UserDefaults.standard.object(forKey: Constants.UserDefaults.forwardInterval.rawValue) == nil {
                return 30.0
            }

            return UserDefaults.standard.double(forKey: Constants.UserDefaults.forwardInterval.rawValue)
        }

        set {
            UserDefaults.standard.set(newValue, forKey: Constants.UserDefaults.forwardInterval.rawValue)

            MPRemoteCommandCenter.shared().skipForwardCommand.preferredIntervals = [newValue] as [NSNumber]
        }
    }
}

// MARK: - Seek Controls

extension PlayerManager {
    func jumpTo(_ time: Double, fromEnd: Bool = false) {
        guard let player = self.audioPlayer else { return }

        player.currentTime = min(max(fromEnd ? player.duration - time : time, 0), player.duration)

        if !self.isPlaying, let currentBook = self.currentBook {
            UserDefaults.standard.set(Date(), forKey: "\(Constants.UserDefaults.lastPauseTime)_\(currentBook.identifier!)")
        }

        self.update()
    }

    func jumpBy(_ direction: Double) {
        guard let player = self.audioPlayer,
            let book = self.currentBook else { return }

        player.currentTime += book.getInterval(from: direction)

        self.update()
    }

    func forward() {
        self.jumpBy(self.forwardInterval)
    }

    func rewind() {
        self.jumpBy(-self.rewindInterval)
    }
}

// MARK: - Playback

extension PlayerManager {
    func play(_ autoplayed: Bool = false) {
        guard let currentBook = self.currentBook, let audioplayer = self.audioPlayer else {
            return
        }

        UserActivityManager.shared.resumePlaybackActivity()

        UserDefaults.standard.set(currentBook.identifier, forKey: Constants.UserDefaults.lastPlayedBook.rawValue)

        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            fatalError("Failed to activate the audio session")
        }

        if self.outputPort == nil {
            self.outputPort = AVAudioSession.sharedInstance().currentRoute.outputs.first
        }

        let completed = Int(audioplayer.duration) == Int(audioplayer.currentTime)

        if autoplayed && completed {
            return
        }

        // If book is completed, reset to start
        if completed {
            audioplayer.currentTime = 0.0
        }

        // Handle smart rewind.
        let lastPauseTimeKey = "\(Constants.UserDefaults.lastPauseTime)_\(currentBook.identifier!)"
        let smartRewindEnabled = UserDefaults.standard.bool(forKey: Constants.UserDefaults.smartRewindEnabled.rawValue)

        if smartRewindEnabled, let lastPlayTime: Date = UserDefaults.standard.object(forKey: lastPauseTimeKey) as? Date {
            let timePassed = Date().timeIntervalSince(lastPlayTime)
            let timePassedLimited = min(max(timePassed, 0), Constants.SmartRewind.threshold.rawValue)

            let delta = timePassedLimited / Constants.SmartRewind.threshold.rawValue

            // Using a cubic curve to soften the rewind effect for lower values and strengthen it for higher
            let rewindTime = pow(delta, 3) * Constants.SmartRewind.maxTime.rawValue
            let newPlayerTime = max(audioplayer.currentTime - rewindTime, 0)

            UserDefaults.standard.set(nil, forKey: lastPauseTimeKey)

            audioplayer.currentTime = newPlayerTime
        }

        // Create timer if needed
        if self.timer == nil || (self.timer != nil && !self.timer.isValid) {
            self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.update), userInfo: nil, repeats: true)

            RunLoop.main.add(self.timer, forMode: RunLoop.Mode.common)
        }

        // Set play state on player and control center
        audioplayer.play()

        self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .bookPlayed, object: nil)
        }

        self.update()
    }

    func pause() {
        guard let audioplayer = self.audioPlayer, let currentBook = self.currentBook else {
            return
        }

        UserActivityManager.shared.stopPlaybackActivity()

        UserDefaults.standard.set(currentBook.identifier, forKey: Constants.UserDefaults.lastPlayedBook.rawValue)

        // Invalidate timer if needed
        if self.timer != nil {
            self.timer.invalidate()
        }

        self.update()

        // Set pause state on player and control center
        audioplayer.pause()

        self.nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 0.0
        self.nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioplayer.currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo

        UserDefaults.standard.set(Date(), forKey: "\(Constants.UserDefaults.lastPauseTime)_\(currentBook.identifier!)")

        try? AVAudioSession.sharedInstance().setActive(false)

        self.outputPort = AVAudioSession.sharedInstance().currentRoute.outputs.first

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .bookPaused, object: nil)
        }
    }

    // Toggle play/pause of book
    func playPause(autoplayed _: Bool = false) {
        guard let audioplayer = self.audioPlayer else { return }

        // Pause player if it's playing
        if audioplayer.isPlaying {
            self.pause()
        } else {
            self.play()
        }
    }

    func stop() {
        // Invalidate timer if needed
        if self.timer != nil {
            self.timer.invalidate()
        }

        self.audioPlayer?.stop()
        self.audioPlayer = nil

        UserActivityManager.shared.stopPlaybackActivity()

        var userInfo: [AnyHashable: Any]?

        if let book = self.currentBook {
            userInfo = ["book": book]
        }

        self.currentBook = nil

        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.lastPlayedBook.rawValue)

        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .bookStopped,
                                            object: nil,
                                            userInfo: userInfo)
        }
    }

    func markAsCompleted(_ flag: Bool) {
        guard let book = self.currentBook,
            let fileURL = book.fileURL else { return }

        book.markAsFinished(flag)
        DataManager.saveContext()

        NotificationCenter.default.post(name: .bookEnd,
                                        object: nil,
                                        userInfo: [
                                            "fileURL": fileURL
        ])
    }
}

// MARK: - AVAudioPlayer Delegate

extension PlayerManager: AVAudioPlayerDelegate {
    // Leave the slider at max
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }

        player.currentTime = player.duration

        UserDefaults.standard.removeObject(forKey: Constants.UserDefaults.lastPlayedBook.rawValue)

        self.update()

        guard let nextBook = self.currentBook?.nextBook() else { return }

        self.load(nextBook, completion: { success in
            guard success else { return }

            let userInfo = ["book": nextBook]

            NotificationCenter.default.post(name: .bookChange,
                                            object: nil,
                                            userInfo: userInfo)
        })
    }
}
