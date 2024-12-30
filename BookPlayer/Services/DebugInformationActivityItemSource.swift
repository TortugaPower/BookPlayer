//
//  DebugInformationActivityItemSource.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 5/1/24.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

import LinkPresentation

/// Share the debug information as a single String
class DebugInformationActivityItemSource: NSObject, UIActivityItemSource {
  let title = "Debug information"
  let info: String

  init(info: String) {
    self.info = info
    super.init()
  }

  func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
    return info
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    itemForActivityType activityType: UIActivity.ActivityType?
  ) -> Any? {
    return info
  }

  func activityViewController(
    _ activityViewController: UIActivityViewController,
    subjectForActivityType activityType: UIActivity.ActivityType?
  ) -> String {
    return title
  }

  func activityViewControllerLinkMetadata(
    _ activityViewController: UIActivityViewController
  ) -> LPLinkMetadata? {
    let metadata = LPLinkMetadata()
    metadata.title = title
    metadata.iconProvider = NSItemProvider(object: UIImage(systemName: "line.3.horizontal")!)
    return metadata
  }
}
