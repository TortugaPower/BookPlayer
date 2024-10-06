//
//  BookPlayerWidgetUI.swift
//  BookPlayerWidgetUI
//
//  Created by Gianni Carlo on 21/11/20.
//  Copyright © 2020 Tortuga Power. All rights reserved.
//

import SwiftUI
import WidgetKit

#if os(watchOS)
  import BookPlayerWatchKit
#else
  import BookPlayerKit
#endif

#if os(iOS)
  struct BookPlayerWidgetUI_Previews: PreviewProvider {
    static var previews: some View {
      Group {
        LastPlayedWidgetView(
          entry: .init(
            date: Date(),
            items: [
              .init(relativePath: "path1", title: "Test Book Title")
            ],
            currentlyPlaying: nil
          )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
      }
    }
  }
#endif

@main
struct BookPlayerBundle: WidgetBundle {
  @WidgetBundleBuilder
  var body: some Widget {
    #if os(iOS)
      LastPlayedWidget()
      TimeListenedWidget()
      if #available(iOSApplicationExtension 16.1, *) {
        SharedWidget()
        SharedIconWidget()
      }
      if #available(iOSApplicationExtension 18.0, *) {
        PlayLastControlWidgetView()
      }
    #elseif os(watchOS)
      SharedWidget()
      SharedIconWidget()
    #endif
  }
}
