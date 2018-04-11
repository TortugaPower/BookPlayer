//
//  Book.swift
//  Audiobook Player
//
//  Created by Florian Pichler on 09.04.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import AVFoundation

struct Book {
    var identifier: String {
        return self.fileURL.lastPathComponent
    }

    var duration: TimeInterval {
        return TimeInterval(CMTimeGetSeconds(self.asset.duration))
    }

    var displayTitle: String {
        return title + " - " + author
    }
    var title: String
    var author: String
    var artwork: UIImage
    var asset: AVAsset
    var fileURL: URL

    var chapters: [Chapter]?
}
