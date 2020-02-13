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
        self.setTitle("library_title".localized)
    }
}
