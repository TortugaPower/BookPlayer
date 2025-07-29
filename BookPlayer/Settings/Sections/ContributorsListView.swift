//
//  ContributorsListView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ContributorsListView: View {
  @State var contributors = [Contributor]()
  @State var gianni = Contributor.gianni
  @State var pichfl = Contributor.pichfl

  let availableWidth: CGFloat
  let contributorsURL = URL(string: "https://api.github.com/repos/TortugaPower/BookPlayer/contributors")!

  private let itemLength: CGFloat = 35
  private let spacing = CGFloat(Spacing.S1)

  var body: some View {
    let columns = Int(availableWidth / (itemLength + spacing))
    let gridItems = Array(repeating: GridItem(.flexible(), spacing: spacing), count: max(columns, 1))

    LazyVGrid(columns: gridItems, spacing: spacing) {
      ForEach(contributors, id: \.self) { contributor in
        ContributorView(
          contributor: contributor,
          length: itemLength
        )
      }
    }
    .onAppear {
      let task = URLSession.shared.dataTask(with: contributorsURL) { data, _, _ in
        guard let data = data,
          let contributors = try? JSONDecoder().decode([Contributor].self, from: data)
        else { return }

        DispatchQueue.main.async {
          self.contributors = contributors.filter { (contributor) -> Bool in
            contributor.id != self.gianni.id && contributor.id != self.pichfl.id
          }
        }
      }

      task.resume()
    }
  }
}

#Preview {
  ContributorsListView(availableWidth: 300)
}
