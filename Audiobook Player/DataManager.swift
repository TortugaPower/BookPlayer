//
//  DataManager.swift
//  Audiobook Player
//
//  Created by Gianni Carlo on 5/30/17.
//  Copyright © 2017 Tortuga Power. All rights reserved.
//

import Foundation

class DataManager {
    
    static let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!
    
    /**
     *  Load local files and process them (rename them if necessary)
     *  Spaces in file names can cause side effects when trying to load the data
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
    
    class func process(_ files:inout [String], urls:inout [URL]){
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
