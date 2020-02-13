//
//  LocalizableButton.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/13/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import UIKit

class LocalizableButton: UIButton {
    @IBInspectable var localizedKey: String? {
        didSet {
            guard let key = localizedKey else { return }

            UIView.performWithoutAnimation {
                setTitle(key.localized, for: .normal)
                layoutIfNeeded()
            }
        }
    }
}
