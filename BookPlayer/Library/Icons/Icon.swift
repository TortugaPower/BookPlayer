//
//  Icon.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/19/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import Foundation

struct Icon: Codable {
    var id: String
    var title: String
    private var artist: String?
    var imageName: String
    private var locked: Bool?

    var isLocked: Bool {
        return self.locked ?? false
    }

    var author: String {
        return self.artist ?? "By your friends from BookPlayer"
    }
}
