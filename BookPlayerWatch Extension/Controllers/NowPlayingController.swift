//
//  NowPlayingController.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 5/12/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import WatchKit

class NowPlayingController: WKInterfaceController {
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        NotificationCenter.default.addObserver(self, selector: #selector(self.bookPlayedNotification), name: .bookPlayed, object: nil)
    }

    @objc func bookPlayedNotification() {
        self.becomeCurrentPage()

        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
            WKInterfaceController.reloadRootPageControllers(withNames: ["LibraryInterfaceController", "NowPlayingController"], contexts: nil, orientation: .horizontal, pageIndex: 1)
        }
    }
}
