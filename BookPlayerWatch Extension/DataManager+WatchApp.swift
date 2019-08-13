//
//  DataManager+WatchApp.swift
//  BookPlayerWatch Extension
//
//  Created by Gianni Carlo on 4/27/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit

extension DataManager {
    public static let dataUrl = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask).first!
        .appendingPathComponent("library.data")

    public class func loadLibrary() -> Library {
        return self.decodeLibrary(FileManager.default.contents(atPath: self.dataUrl.path))
            ?? Library(context: self.getContext())
    }

    public class func decodeLibrary(_ data: Data?) -> Library? {
        guard let data = data else { return nil }

        try? data.write(to: DataManager.dataUrl)

        let bgContext = DataManager.getBackgroundContext()
        let decoder = JSONDecoder()

        guard let context = CodingUserInfoKey.context else { return nil }

        decoder.userInfo[context] = bgContext

        guard let library = try? decoder.decode(Library.self, from: data) else {
            return nil
        }

        return library
    }
}
