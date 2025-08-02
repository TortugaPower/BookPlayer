//
//  QueuedSyncTaskRowView.swift
//  BookPlayer
//
//  Created by gianni.carlo on 26/5/23.
//  Copyright © 2023 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct QueuedSyncTaskRowView: View {
  @Binding var imageName: String
  @Binding var title: String

  @EnvironmentObject var themeViewModel: ThemeViewModel

  var body: some View {
    HStack {
      Image(systemName: imageName)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 20, height: 20)
        .foregroundStyle(themeViewModel.secondaryColor)
        .padding([.trailing], 5)
      Text(title)
        .font(Font(Fonts.body))
        .foregroundStyle(themeViewModel.primaryColor)
    }
    .padding([.vertical], 3)
  }
}

struct QueuedSyncTaskRowView_Previews: PreviewProvider {
  static var previews: some View {
    QueuedSyncTaskRowView(
      imageName: .constant("bookmark"),
      title: .constant("Task")
    )
    .environmentObject(ThemeViewModel())
  }
}
