//
//  ContributorView.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 25/7/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Kingfisher
import SwiftUI

struct ContributorView: View {
  let contributor: Contributor
  var title: String?
  let length: CGFloat

  @Environment(\.openURL) private var openURL

  var body: some View {
    Button {
      openURL(contributor.profileURL)
    } label: {
      VStack(alignment: .center) {
        KFImage
          .url(contributor.avatarURL)
          .resizable()
          .fade(duration: 0.5)
          .frame(width: length, height: length)
          .mask(Circle())
        if let title {
          Text(title)
            .bpFont(Fonts.caption)
        }
      }
    }
    .buttonStyle(.plain)
  }
}

struct Contributor: Decodable, Identifiable, Hashable {
  var id: Int
  var login: String
  var html_url: String
  var avatar_url: String

  var avatarURL: URL {
    return URL(string: self.avatar_url)!
  }

  var profileURL: URL {
    return URL(string: self.html_url)!
  }
}

extension Contributor {
  static let gianni: Contributor = .init(
    id: 14_112_819,
    login: "GianniCarlo",
    html_url: "https://github.com/GianniCarlo",
    avatar_url: "https://avatars2.githubusercontent.com/u/14112819?v=4"
  )

  static let pichfl: Contributor = .init(
    id: 194641,
    login: "pichfl",
    html_url: "https://github.com/pichfl",
    avatar_url: "https://avatars2.githubusercontent.com/u/194641?v=4"
  )
}

#Preview {
  ContributorView(contributor: .gianni, title: "@GianniCarlo", length: 70)
}
