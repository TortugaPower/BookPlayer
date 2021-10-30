//
//  LocalizableLabel.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/11/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import UIKit

class LocalizableLabel: UILabel {
    @IBInspectable var localizedKey: String? {
        didSet {
            guard let key = localizedKey else { return }

            text = key.localized
        }
    }
}
