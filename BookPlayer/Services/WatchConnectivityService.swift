//
//  WatchConnectivityService.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 10/20/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import WatchConnectivity

class WatchConnectivityService: NSObject, WCSessionDelegate {

    static let shared = WatchConnectivityService()
    private override init() {
        super.init()
    }

    private let session: WCSession? = WCSession.isSupported() ? WCSession.default : nil

    private var validSession: WCSession? {

        // paired - the user has to have their device paired to the watch
        // watchAppInstalled - the user must have your watch app installed

        // Note: if the device is paired, but your watch app is not installed
        // consider prompting the user to install it for a better experience

        if let session = session, session.isPaired, session.isWatchAppInstalled {
            return session
        }
        return nil
    }

    func startSession() {
        session?.delegate = self
        session?.activate()
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("======= activated")
        print(error)
    }
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("====== inactive")
    }
    func sessionDidDeactivate(_ session: WCSession) {
        print("====== deactivating")
    }
}

extension WatchConnectivityService {
    func updateApplicationContext(_ applicationContext: [String: Any]) throws {
        if let session = self.validSession {
            do {
                try session.updateApplicationContext(applicationContext)
            } catch let error {
                throw error
            }
        }
    }

    func transferFile(_ file: URL, metadata: [String: Any]?) throws {
        if let session = self.validSession {
            do {
                session.transferFile(file, metadata: metadata)
            } catch let error {
                throw error
            }
        }
    }
}
