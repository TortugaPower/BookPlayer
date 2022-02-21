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
  var items = [
    PlayableItem(
      title: "542: Apologetic Beavers",
      author: "Grumpy old geeks",
      chapters: [
        PlayableChapter(
          title: "Chapter 1",
          author: "Author",
          start: 0,
          duration: 0,
          relativePath: "",
          index: 0
        ),
        PlayableChapter(
          title: "Chapter 2",
          author: "Author",
          start: 0,
          duration: 0,
          relativePath: "",
          index: 1
        ),
        PlayableChapter(
          title: "Chapter 3",
          author: "Author",
          start: 0,
          duration: 0,
          relativePath: "",
          index: 2
        ),
        PlayableChapter(
          title: "Chapter 4",
          author: "Author",
          start: 0,
          duration: 0,
          relativePath: "",
          index: 3
        ),
        PlayableChapter(
          title: "Chapter 5",
          author: "Author",
          start: 0,
          duration: 0,
          relativePath: "",
          index: 4
        )
      ],
      currentTime: 0,
      duration: 0,
      relativePath: "book 1",
      percentCompleted: 0,
      isFinished: false,
      useChapterTimeContext: false
    ),
    PlayableItem(
      title: "book 2 book 2 book 2 book 2 book 2",
      author: "author 2 author 2 author 2 author 2 author 2",
      chapters: [PlayableChapter(
        title: "Chapter 1",
        author: "Author",
        start: 0,
        duration: 0,
        relativePath: "",
        index: 0
      )],
      currentTime: 0,
      duration: 0,
      relativePath: "book 2",
      percentCompleted: 0,
      isFinished: false,
      useChapterTimeContext: false
    ),
    PlayableItem(
      title: "book 3",
      author: "author 3",
      chapters: [PlayableChapter(
        title: "Chapter 1",
        author: "Author",
        start: 0,
        duration: 0,
        relativePath: "",
        index: 0
      )],
      currentTime: 0,
      duration: 0,
      relativePath: "book 3",
      percentCompleted: 0,
      isFinished: false,
      useChapterTimeContext: false
    ),
    PlayableItem(
      title: "book 4",
      author: "author 4",
      chapters: [PlayableChapter(
        title: "Chapter 1",
        author: "Author",
        start: 0,
        duration: 0,
        relativePath: "",
        index: 0
      )],
      currentTime: 0,
      duration: 0,
      relativePath: "book 4",
      percentCompleted: 0,
      isFinished: false,
      useChapterTimeContext: false
    ),
    PlayableItem(
      title: "book 5",
      author: "author 5",
      chapters: [PlayableChapter(
        title: "Chapter 1",
        author: "Author",
        start: 0,
        duration: 0,
        relativePath: "",
        index: 0
      )],
      currentTime: 0,
      duration: 0,
      relativePath: "book 5",
      percentCompleted: 0,
      isFinished: false,
      useChapterTimeContext: false
    ),
    PlayableItem(
      title: "book 6",
      author: "author 6",
      chapters: [PlayableChapter(
        title: "Chapter 1",
        author: "Author",
        start: 0,
        duration: 0,
        relativePath: "",
        index: 0
      )],
      currentTime: 0,
      duration: 0,
      relativePath: "book 6",
      percentCompleted: 0,
      isFinished: false,
      useChapterTimeContext: false
    ),
    PlayableItem(
      title: "book 7",
      author: "author 7",
      chapters: [PlayableChapter(
        title: "Chapter 1",
        author: "Author",
        start: 0,
        duration: 0,
        relativePath: "",
        index: 0
      )],
      currentTime: 0,
      duration: 0,
      relativePath: "book 7",
      percentCompleted: 0,
      isFinished: false,
      useChapterTimeContext: false
    )
  ]
}
