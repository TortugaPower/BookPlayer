//
//  CreditsViewController.swift
//  BookPlayer
//
//  Created by Florian Pichler on 06.05.18.
//  Copyright © 2018 Tortuga Power. All rights reserved.
//

import UIKit
import WebKit

class CreditsViewController: UIViewController {
    @IBOutlet private weak var textView: UITextView!

    var content: String!

    override func loadView() {
        super.loadView()

        guard let filepath = Bundle.main.path(forResource: "Credits", ofType: "html") else {
            return
        }

        var contents: String

        do {
            contents = try String(contentsOfFile: filepath)
        } catch {
            contents = "Unable to display credits"
        }

        do {
            let data = NSString(string: contents).data(using: String.Encoding.unicode.rawValue)!
            let options = [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html]
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)

            self.textView.attributedText = attributedString

            self.textView.linkTextAttributes = convertToOptionalNSAttributedStringKeyDictionary([
                NSAttributedString.Key.foregroundColor.rawValue: UIColor.tintColor,
                NSAttributedString.Key.underlineColor.rawValue: UIColor.tintColor,
                NSAttributedString.Key.underlineStyle.rawValue: NSUnderlineStyle.single.rawValue
            ])
        } catch {
            self.textView.text = contents
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.textView.textContainerInset = UIEdgeInsets(top: 10.0, left: 13.0, bottom: 0, right: 13.0)
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToOptionalNSAttributedStringKeyDictionary(_ input: [String: Any]?) -> [NSAttributedString.Key: Any]? {
    guard let input = input else { return nil }
    return Dictionary(uniqueKeysWithValues: input.map { key, value in (NSAttributedString.Key(rawValue: key), value) })
}
