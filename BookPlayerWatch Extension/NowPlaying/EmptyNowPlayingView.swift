//
//  EmptyNowPlayingView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 26/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import SwiftUI

struct EmptyNowPlayingView: View {
  var body: some View {
    VStack {
      NowPlayingTitleView(author: "-", title: "-")
      Spacer()
      HStack {
        ZStack {
          Text("**300**")
            .minimumScaleFactor(0.1)
            .lineLimit(1)
            .padding(5)
            .offset(y: 1)
          ResizeableImageView(name: "gobackward")
        }
        .padding(14)
        .opacity(0.5)
        ProgressView()
          .padding(8)
          .opacity(0.5)
        ZStack {
          Text("**30**")
            .minimumScaleFactor(0.1)
            .lineLimit(1)
            .padding(5)
            .offset(y: 1)
          ResizeableImageView(name: "goforward")
        }
        .padding(14)
        .opacity(0.5)
      }

      Spacer()
      HStack {
        ResizeableImageView(name: "dial.max")
          .padding(11)
          .opacity(0.5)
        VolumeView()
        ResizeableImageView(name: "list.bullet")
          .padding(14)
          .opacity(0.5)
      }
    }
    .ignoresSafeArea(edges: .bottom)
  }
}

struct EmptyNowPlayingView_Previews: PreviewProvider {
  static var previews: some View {
    EmptyNowPlayingView()
  }
}
