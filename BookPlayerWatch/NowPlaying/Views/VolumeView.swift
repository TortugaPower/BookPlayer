//
//  VolumeView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 19/2/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct VolumeView: WKInterfaceObjectRepresentable {
  typealias WKInterfaceObjectType = WKInterfaceVolumeControl
  let type: WKInterfaceVolumeControl.Origin

  func makeWKInterfaceObject(context: Self.Context) -> WKInterfaceVolumeControl {
    return WKInterfaceVolumeControl(origin: type)
  }

  func updateWKInterfaceObject(_ wkInterfaceObject: WKInterfaceVolumeControl, context: WKInterfaceObjectRepresentableContext<VolumeView>) {
  }
}

struct VolumeView_Previews: PreviewProvider {
  static var previews: some View {
    VolumeView(type: .companion)
  }
}
