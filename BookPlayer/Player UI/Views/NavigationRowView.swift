//
//  NavigationRowView.swift
//  BookPlayer
//
//  Created by Pedro Iñiguez on 9/2/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import SwiftUI

struct NavigationRowView: View {
    var body: some View {
      HStack {
        HStack(spacing: 16) {
          Image(systemName: "chevron.left.2")
          Image(systemName: "chevron.left")
        }
        
        Spacer()
        
        Text("Now Playing")
          .font(.headline)
        
        Spacer()
        
        HStack(spacing: 16) {
          Image(systemName: "chevron.right")
          Image(systemName: "chevron.right.2")
        }
      }
    }
}

#Preview {
    NavigationRowView()
}
