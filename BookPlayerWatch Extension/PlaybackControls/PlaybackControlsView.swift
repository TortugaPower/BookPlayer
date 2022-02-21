//
//  PlaybackControlsView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 20/2/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import SwiftUI

struct PlaybackControlsView: View {
  @State private var boostVolumeEnabled = false

  var body: some View {
    GeometryReader { metrics in
      VStack {
        HStack {
          Spacer()
          Button {
            print("rewind tapped")
          } label: {
            ResizeableImageView(name: "minus.circle")
          }
          .buttonStyle(PlainButtonStyle())
          .frame(width: metrics.size.width * 0.15)
          Spacer()
            .padding([.leading], 5)
          Button {
            print("play tapped")
          } label: {
            Text("3.35x")
              .padding()
              .frame(maxWidth: .infinity)
              .background(Color.black.brightness(0.2))
              .cornerRadius(5)
          }
          .buttonStyle(PlainButtonStyle())
          .frame(width: metrics.size.width * 0.4)

          Spacer()
            .padding([.leading], 5)
          Button {
            print("forward tapped")
          } label: {
            ResizeableImageView(name: "plus.circle")
          }
          .buttonStyle(PlainButtonStyle())
          .frame(width: metrics.size.width * 0.15)
          Spacer()
        }
        .padding([.top], 10)
        List {
          Toggle("settings_boostvolume_title", isOn: $boostVolumeEnabled)
        }
        .padding([.top], 10)
        Spacer()
      }
    }
    .navigationTitle("settings_controls_title")
  }
}

struct PlaybackControlsView_Previews: PreviewProvider {
  static var previews: some View {
    PlaybackControlsView()
  }
}
