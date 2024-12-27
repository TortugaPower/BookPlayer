//
//  ResizeableImageView.swift
//  BookPlayerWatch Extension
//
//  Created by gianni.carlo on 20/2/22.
//  Copyright © 2022 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct ResizeableImageView: View {
  let name: String

  var body: some View {
    Image(systemName: name)
      .resizable()
      .renderingMode(.template)
      .aspectRatio(contentMode: .fit)
  }
}

struct ResizeableImageView_Previews: PreviewProvider {
  static var previews: some View {
    ResizeableImageView(name: "play.fill")
  }
}
