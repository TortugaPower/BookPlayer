//
//  String+BookPlayer.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/11/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import UIKit

extension String {
    public var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { return self }
}
