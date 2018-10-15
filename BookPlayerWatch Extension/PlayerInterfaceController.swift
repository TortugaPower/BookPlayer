//
//  PlayerInterfaceController.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 10/14/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import WatchKit

class PlayerInterfaceController: WKInterfaceController {
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        // Configure interface objects here.
        NotificationCenter.default.addObserver(self, selector: #selector(self.derp), name: NSNotification.Name(rawValue: "derp"), object: nil)
    }

    @objc func derp() {
        super.becomeCurrentPage()
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
}
