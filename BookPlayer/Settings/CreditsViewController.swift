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
    @IBOutlet private var textView: UITextView!

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

            textView.attributedText = attributedString

            textView.linkTextAttributes = [
                NSAttributedStringKey.foregroundColor.rawValue: UIColor.tintColor,
                NSAttributedStringKey.underlineColor.rawValue: UIColor.tintColor,
                NSAttributedStringKey.underlineStyle.rawValue: NSUnderlineStyle.styleSingle.rawValue,
            ]
        } catch {
            textView.text = contents
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        textView.textContainerInset = UIEdgeInsets(top: 10.0, left: 13.0, bottom: 0, right: 13.0)
    }
}
