//
//  BookPlayerWidgetUI.swift
//  BookPlayerWidgetUI
//
//  Created by Gianni Carlo on 21/11/20.
//  Copyright © 2020 BookPlayer LLC. All rights reserved.
//

import SwiftUI
import WidgetKit

#if os(watchOS)
  import BookPlayerWatchKit
#else
  import BookPlayerKit
#endif

@main
struct BookPlayerBundle {
  static func main() {
#if os(iOS)
    IOSWidgetsBundle.main()
#elseif os(watchOS)
    WatchWidgetsBundle.main()
#endif
  }

#if os(iOS)
  struct IOSWidgetsBundle: WidgetBundle {
    var body: some Widget {
      LastPlayedWidget()
      TimeListenedWidget()
      SharedWidget()
      SharedIconWidget()
      PlayLastControlWidgetView()
    }
  }

#elseif os(watchOS)
  struct WatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
      SharedWidget()
      SharedIconWidget()
    }
  }
#endif
}
