//
//  WatchConnectivityService.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 10/20/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import WatchConnectivity

class WatchConnectivityService: NSObject, WCSessionDelegate {

    static let sharedManager = WatchConnectivityService()
    private override init() {
        super.init()
    }

    private let session: WCSession = WCSession.default

    func startSession() {
        session.delegate = self
        session.activate()
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("Session activation did complete")
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        print("========= derp: ", applicationContext)
    }

    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        print("======= received file: ", file)
    }
}
