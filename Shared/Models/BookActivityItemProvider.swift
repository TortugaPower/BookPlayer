//
//  BookActivityItemProvider.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/28/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

public class BookActivityItemProvider: UIActivityItemProvider {
    var book: Book
    public init(_ book: Book) {
        self.book = book
        super.init(placeholderItem: book)
    }

    override public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempUrl = tempDir.appendingPathComponent(self.book.filename)

        guard let fileURL = self.book.fileURL else { return nil }

        try? FileManager.default.copyItem(at: fileURL, to: tempUrl)

        return tempUrl
    }

    override public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return URL(fileURLWithPath: "placeholder")
    }
}
