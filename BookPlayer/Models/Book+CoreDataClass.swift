//
//  Book+CoreDataClass.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/9/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//
//

import Foundation
import CoreData
import AVFoundation


public class Book: LibraryItem {
    var fileURL: URL!
    var asset: AVAsset!
    var currentChapter: Chapter!
    var displayTitle: String {
        return self.title
    }
    
    func load(fileURL: URL){
        self.fileURL = fileURL
        autoreleasepool { () -> Void in
            self.asset = AVAsset(url: fileURL)
        }
    }

    convenience init(from fileURL: URL, context: NSManagedObjectContext) {
        let entity = NSEntityDescription.entity(forEntityName: "Book", in: context)!
        self.init(entity: entity, insertInto: context)
        self.fileURL = fileURL
        self.identifier = fileURL.lastPathComponent
        self.asset = AVAsset(url: fileURL)
        
        let titleFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String
        let authorFromMeta = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String
    
        self.title = titleFromMeta ?? fileURL.lastPathComponent.replacingOccurrences(of: "_", with: " ")
        self.author = authorFromMeta ?? "Unknown Author"
        self.duration = CMTimeGetSeconds(self.asset.duration)
        
        self.artwork = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? NSData
    
    }
}
