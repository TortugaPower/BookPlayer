//
//  ThemedSection.swift
//  BookPlayer
//
//  Created by Gianni Carlo on 2/7/26.
//  Copyright © 2026 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import SwiftUI

struct ThemedSection<Content: View, Header: View, Footer: View>: View {
  @EnvironmentObject var theme: ThemeViewModel

  private let content: Content
  private let header: Header?
  private let footer: Footer?

  var body: some View {
    Group {
      if let header = header, let footer = footer {
        Section {
          content
        } header: {
          header
        } footer: {
          footer
        }
      } else if let header = header {
        Section {
          content
        } header: {
          header
        }
      } else if let footer = footer {
        Section {
          content
        } footer: {
          footer
        }
      } else {
        Section {
          content
        }
      }
    }
    .listRowBackground(theme.tertiarySystemBackgroundColor)
  }
}

// MARK: - Initializers matching Section's API

extension ThemedSection where Header == EmptyView, Footer == EmptyView {
  init(@ViewBuilder content: () -> Content) {
    self.content = content()
    self.header = nil
    self.footer = nil
  }
}

extension ThemedSection where Footer == EmptyView {
  init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
    self.content = content()
    self.header = header()
    self.footer = nil
  }
}

extension ThemedSection where Header == Text, Footer == EmptyView {
  init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {
    self.content = content()
    self.header = Text(titleKey)
    self.footer = nil
  }

  init(_ title: String, @ViewBuilder content: () -> Content) {
    self.content = content()
    self.header = Text(title)
    self.footer = nil
  }
}

extension ThemedSection where Header == EmptyView {
  init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {
    self.content = content()
    self.header = nil
    self.footer = footer()
  }
}

extension ThemedSection {
  init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header, @ViewBuilder footer: () -> Footer) {
    self.content = content()
    self.header = header()
    self.footer = footer()
  }
}

#Preview {
  ThemedSection {
    Text("This is a row")
  }
}
