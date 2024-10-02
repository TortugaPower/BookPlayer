//
//  LaunchAppControlWidgetView.swift
//  BookPlayerWidgetsPhone
//
//  Created by Gianni Carlo on 1/10/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import AppIntents
import Foundation
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 18.0, iOS 18.0, *)
struct LaunchAppButton: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(
      kind: "com.bookplayer.controlcenter.launchapp"
    ) {
      ControlWidgetButton(action: LaunchAppIntent()) {
        Label("BookPlayer", image: "bookplayer.icon")
      }
    }
    .displayName("BookPlayer")
  }
}

@available(iOSApplicationExtension 16, iOS 16.0, *)
struct LaunchAppIntent: OpenIntent {
  static var title: LocalizedStringResource = "Launch App"
  @Parameter(title: "Target")
  var target: LaunchAppEnum
}

@available(iOSApplicationExtension 16.0, iOS 16.0, *)
enum LaunchAppEnum: String, AppEnum {
  case home

  static var typeDisplayRepresentation = TypeDisplayRepresentation("BookPlayer Home")
  static var caseDisplayRepresentations = [
    LaunchAppEnum.home: DisplayRepresentation("Home")
  ]
}
