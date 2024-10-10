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

@main
struct BookPlayerBundle {
  static func main() {
#if os(iOS)
    if #available(iOSApplicationExtension 18.0, *) {
      IOSWidgetsBundle18.main()
    } else if #available(iOSApplicationExtension 16.1, *) {
      IOSWidgetsBundle16.main()
    } else {
      IOSWidgetsBundle.main()
    }
#elseif os(watchOS)
    WatchWidgetsBundle.main()
#endif
  }

#if os(iOS)
  struct IOSWidgetsBundle: WidgetBundle {
    var body: some Widget {
      LastPlayedWidget()
      TimeListenedWidget()
    }
  }

  @available(iOSApplicationExtension 16.1, *)
  struct IOSWidgetsBundle16: WidgetBundle {
    var body: some Widget {
      LastPlayedWidget()
      TimeListenedWidget()
      SharedWidget()
      SharedIconWidget()
    }
  }

  @available(iOSApplicationExtension 18.0, *)
  struct IOSWidgetsBundle18: WidgetBundle {
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
