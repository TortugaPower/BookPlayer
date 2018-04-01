//
//  MoreOptions.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 01.04.18.
//  Copyright © 2018 Florian Pichler.
//

import UIKit

class MoreOptions {
    static let shared = MoreOptions()

    private init() { }

    func actionSheet(actions: [UIAlertAction]) -> UIAlertController {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        for action in actions {
            alert.addAction(action)
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        return alert
    }
}
