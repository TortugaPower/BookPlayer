//
//  VolumeView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 19/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import SwiftUI

struct VolumeView: WKInterfaceObjectRepresentable {
  typealias WKInterfaceObjectType = WKInterfaceVolumeControl

  func makeWKInterfaceObject(context: Self.Context) -> WKInterfaceVolumeControl {
    return WKInterfaceVolumeControl(origin: .companion)
  }

  func updateWKInterfaceObject(_ wkInterfaceObject: WKInterfaceVolumeControl, context: WKInterfaceObjectRepresentableContext<VolumeView>) {
  }
}

struct VolumeView_Previews: PreviewProvider {
  static var previews: some View {
    VolumeView()
  }
}
