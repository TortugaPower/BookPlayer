//
//  BookmarkTableViewCell.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 6/9/21.
//  Copyright © 2021 Tortuga Power. All rights reserved.
//

import BookPlayerKit
import Combine
import Themeable
import UIKit

class BookmarkTableViewCell: UITableViewCell {
  @IBOutlet weak var timeLabel: UILabel!
  @IBOutlet weak var noteLabel: UILabel!
  @IBOutlet weak var iconImageView: UIImageView!

  private var timeSubscription: AnyCancellable?
  private var noteSubscription: AnyCancellable?
  private var iconTypeSubscription: AnyCancellable?

  override func awakeFromNib() {
    super.awakeFromNib()

    self.iconImageView.contentMode = .scaleAspectFill
    setUpTheming()
  }

  func setup(with bookmark: Bookmark) {
    self.timeSubscription = bookmark.publisher(for: \.time)
      .map({ TimeParser.formatTime($0) })
      .assign(to: \.text, on: timeLabel)

    self.noteSubscription = bookmark.publisher(for: \.note)
      .assign(to: \.text, on: noteLabel)

    self.iconTypeSubscription = bookmark.publisher(for: \.type)
      .map({ _ in
        if let imageName = bookmark.getImageNameForType() {
          return UIImage(systemName: imageName)
        } else {
          return nil
        }
      })
      .assign(to: \.image, on: iconImageView)
  }
}

extension BookmarkTableViewCell: Themeable {
  func applyTheme(_ theme: SimpleTheme) {
    self.timeLabel?.textColor = theme.secondaryColor
    self.noteLabel?.textColor = theme.primaryColor
    self.iconImageView.tintColor = theme.secondaryColor
    self.backgroundColor = theme.systemBackgroundColor
  }
}
