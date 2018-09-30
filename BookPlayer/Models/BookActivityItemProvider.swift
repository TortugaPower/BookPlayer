//
//  BookActivityItemProvider.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/28/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import BookPlayerKit

class BookActivityItemProvider: UIActivityItemProvider {
    var book: Book
    public init(_ book: Book) {
        self.book = book
        super.init(placeholderItem: book)
    }

    override func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivityType?) -> Any? {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempUrl = tempDir.appendingPathComponent(self.book.filename)

        try? FileManager.default.copyItem(at: self.book.fileURL, to: tempUrl)

        return tempUrl
    }

    override func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return self.book.fileURL
    }
}
