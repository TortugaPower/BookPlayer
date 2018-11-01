//
//  BookActivityItemProvider.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 9/28/18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit

class BookActivityItemProvider: UIActivityItemProvider {
    var book: Book
    public init(_ book: Book) {
        self.book = book
        super.init(placeholderItem: book)
    }

    override func activityViewController(_: UIActivityViewController, itemForActivityType _: UIActivityType?) -> Any? {
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let tempUrl = tempDir.appendingPathComponent(book.filename)

        try? FileManager.default.copyItem(at: book.fileURL, to: tempUrl)

        return tempUrl
    }

    override func activityViewControllerPlaceholderItem(_: UIActivityViewController) -> Any {
        return book.fileURL
    }
}
