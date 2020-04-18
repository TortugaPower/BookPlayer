//
//  TodayViewController.swift
//  BookPlayerWidget
//
//  Created by Gianni Carlo on 4/24/19.
//  Copyright © 2019 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import NotificationCenter
import UIKit

class TodayViewController: UIViewController, NCWidgetProviding {
    @IBOutlet weak var artworkImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var authorLabel: UILabel!
    @IBOutlet weak var chapterLabel: UILabel!
    @IBOutlet weak var playButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        self.artworkImageView.layer.cornerRadius = 4.0
        self.artworkImageView.layer.masksToBounds = true
        self.artworkImageView.clipsToBounds = true

        self.artworkImageView.layer.borderWidth = 0.5
        self.artworkImageView.layer.borderColor = UIColor.textColor.withAlphaComponent(0.2).cgColor
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        self.updateBookDetails()
    }

    func updateBookDetails() {
        let library = DataManager.getLibrary()

        guard let book = library.lastPlayedBook else { return }

        self.artworkImageView.image = book.artwork
        self.titleLabel.text = book.title
        self.authorLabel.text = book.author

        if let chapter = book.currentChapter {
            self.chapterLabel.text = chapter.title
            self.chapterLabel.isHidden = false
        } else {
            self.chapterLabel.isHidden = true
        }

        guard let theme = library.currentTheme else { return }

        let titleColor = theme.primaryColor.mix(with: theme.detailColor)

        self.view.backgroundColor = theme.backgroundColor.withAlpha(newAlpha: 0.5)
        self.authorLabel.textColor = theme.primaryColor
        self.titleLabel.textColor = titleColor
        self.chapterLabel.textColor = titleColor
        self.playButton.tintColor = theme.highlightColor
    }

    func widgetPerformUpdate(completionHandler: @escaping (NCUpdateResult) -> Void) {
        self.updateBookDetails()
        completionHandler(NCUpdateResult.newData)
    }

    @IBAction func togglePlay(_ sender: UIButton) {
        let parameter = URLQueryItem(name: "showPlayer", value: "true")
        let actionString = CommandParser.createActionString(from: .play, parameters: [parameter])

        self.extensionContext?.open(URL(string: actionString)!, completionHandler: nil)
    }
}
