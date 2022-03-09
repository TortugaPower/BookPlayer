//
//  ItemListModel.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 18/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import Foundation
import SwiftUI
import Combine

class ItemListModel: ObservableObject {
  let watchConnectivityService: WatchConnectivityService

  @Published var items = [PlayableItem]()
  @Published var isLoading = true

  init() {
    self.watchConnectivityService = WatchConnectivityService()
    self.watchConnectivityService.didReceiveData = { [weak self] data in
      let decoder = JSONDecoder()

      if let decodedItems = try? decoder.decode([PlayableItem].self, from: data) {
        DispatchQueue.main.async {
          self?.items = decodedItems
        }
      }
    }
    self.watchConnectivityService.startSession()
    self.items = self.testData()
  }

  func testData() -> [PlayableItem] {
    return [
      PlayableItem(
        title: "test book",
        author: "test author",
        chapters: [
          PlayableChapter(
            title: "chapter 1",
            author: "test author",
            start: 0,
            duration: 100,
            relativePath: "test/book.mp3",
            index: 0
          )
        ],
        currentTime: 0,
        duration: 100,
        relativePath: "test/book.mp3",
        percentCompleted: 0,
        isFinished: false,
        useChapterTimeContext: true
      )
    ]
  }

  func requestData() {
    let encoder = JSONEncoder()
    let data = try! encoder.encode(["command": "refresh"])

    self.watchConnectivityService.sendMessageData(
      data: data,
      replyHandler: self.watchConnectivityService.didReceiveData
    )
  }
}
