//
//  ChapterListView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 20/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import BookPlayerWatchKit
import SwiftUI

struct ChapterListView: View {
  @Environment(\.presentationMode) var presentationMode
  @EnvironmentObject var contextManager: ContextManager
  
  var body: some View {
    ScrollViewReader { proxy in
      List {
        if let currentItem = contextManager.applicationContext.currentItem {
          ForEach(currentItem.chapters) { chapter in
            Button {
              contextManager.handleChapterSelected(chapter)
              presentationMode.wrappedValue.dismiss()
            } label: {
              HStack {
                Text(chapter.title)
                if currentItem.currentChapter.index == chapter.index {
                  Spacer()
                  Image(systemName: "checkmark.circle.fill")
                }
              }
            }
            .id(chapter.index)
          }
        }
      }
      .onAppear {
        if let currentChapter = contextManager.applicationContext.currentItem?.currentChapter {
          proxy.scrollTo(currentChapter.index)
        }
      }
    }
    .navigationTitle("chapters_title")
  }
}
