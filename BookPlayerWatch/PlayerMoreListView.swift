//
//  PlayerMoreListView.swift
//  BookPlayerWatch
//
//  Created by Gianni Carlo on 28/11/24.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct PlayerMoreListView: View {
  var body: some View {
    List {
      Button {
        print("Downloading Book")
      } label: {
        Text("Download Book")
      }
    }
    .environment(\.defaultMinListRowHeight, 40)
  }
}

#Preview {
  PlayerMoreListView()
}
