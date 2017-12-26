//
//  DataManager.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 5/30/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import Foundation
import AVFoundation
import UIKit

struct Book {
    var identifier: String {
        get {
            return self.fileURL.lastPathComponent
        }
    }
    
    var duration: Int {
        get {
            return Int(CMTimeGetSeconds(self.asset.duration))
        }
    }
    
    var title: String
    var author: String
    var artwork: UIImage
    var asset: AVAsset
    var fileURL: URL
}

class DataManager {
    
    static let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    
    /**
     *  Load local files and return array of Books
     */
    class func loadBooks(completion:@escaping ([Book]) -> Void) {
        var books = [Book]()
        //get reference of all the files located inside the Documents folder
        guard let urls = DataManager.getLocalFilesURL() else {
            return completion(books)
        }
        
        DispatchQueue.global().async {
            //iterate and process files
            self.process(urls, books: &books)
            
            DispatchQueue.main.async {
                completion(books)
            }
        }
    }
    
    /**
     *  Return array of file URLs
     */
    class func getLocalFilesURL() -> [URL]? {
        
        //get reference of all the files located inside the Documents folder
        guard let fileEnumerator = FileManager.default.enumerator(atPath: self.documentsPath) else {
            return nil
        }
        var filenameArray = fileEnumerator.map({ return $0}) as! [String]
        
        var urlArray = [URL]()
        self.process(&filenameArray, urls: &urlArray)
        
        return urlArray
    }
    
    /**
     * Create book objects array from
     */
    private class func process(_ urls: [URL], books:inout [Book]){
        
        for fileURL in urls {
            
            //if file already in list, skip to next one
            if books.contains(where: { $0.fileURL == fileURL }) {
                continue
            }
            
            //autoreleasepool needed to avoid OOM crashes from the file manager
            autoreleasepool { () -> () in
                let asset = AVAsset(url: fileURL)
                
                let title = (AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyTitle, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String ?? fileURL.lastPathComponent).replacingOccurrences(of: " ", with: "_")
                
                let author = (AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtist, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? String ?? "Unknown Author").replacingOccurrences(of: " ", with: "_")
                
                var bookCover:UIImage!
                if let artwork = AVMetadataItem.metadataItems(from: asset.metadata, withKey: AVMetadataKey.commonKeyArtwork, keySpace: AVMetadataKeySpace.common).first?.value?.copy(with: nil) as? Data {
                    bookCover = UIImage(data: artwork)
                }else{
                    bookCover = #imageLiteral(resourceName: "defaultBookArt")
                }
                
                let book = Book(title: title, author: author, artwork: bookCover, asset: asset, fileURL: fileURL)
                books.append(book)
            }
        }
        books.sort { (b1, b2) -> Bool in
            return b1.title.compare(b2.title) == .orderedAscending
        }
    }
    
    private class func process(_ files:inout [String], urls:inout [URL]){
        if files.count == 0 {
            return
        }
        
        let filename = files.removeFirst()
        
        //ignore folder inbox
        if filename  == "Inbox" {
            return self.process(&files, urls: &urls)
        }
        
        let documentsURL = URL(fileURLWithPath: self.documentsPath)
        
        // which should return valid url strings
        let fileURL = documentsURL.appendingPathComponent(filename)
        
        //append if file isn't in list
        if !urls.contains(fileURL) {
            urls.append(fileURL)
        }
        
        return self.process(&files, urls: &urls)
    }
}
