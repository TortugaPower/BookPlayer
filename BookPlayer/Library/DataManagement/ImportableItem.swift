//
//  ImportableItem.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/20/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import Foundation

public class ImportableItem: NSObject, NSItemProviderReading {
    let data: Data
    let typeIdentifier: String
    var suggestedName: String?

    var fileExtension: String {
        switch self.typeIdentifier {
        case "public.audio":
            return "mp3"
        case "public.movie":
            return "mp4"
        case "com.pkware.zip-archive":
            return "zip"
        default:
            return "mp3"
        }
    }
    
    required init(dataObject: Data, type: String) {
        data = dataObject
        typeIdentifier = type
    }
    
    public static var readableTypeIdentifiersForItemProvider: [String] {
        return ["public.audio", "com.pkware.zip-archive", "public.movie"]
    }
    
    public static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self {
        return self.init(dataObject: data, type: typeIdentifier)
    }
    
    
}
