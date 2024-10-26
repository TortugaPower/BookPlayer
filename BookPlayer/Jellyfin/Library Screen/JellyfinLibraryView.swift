//
//  JellyfinLibraryView.swift
//  BookPlayer
//
//  Created by Lysann Schlegel on 2024-10-26.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

import SwiftUI

struct JellyfinLibraryView: View {
  @ObservedObject var viewModel: JellyfinLibraryViewModel
  @StateObject var themeViewModel = ThemeViewModel()

  struct UserView: View {
    let name: String
    var body: some View {
      ZStack {
        Text(name)
          .font(.title)
          .multilineTextAlignment(.center)
      }
      .frame(width: 100, height: 100)
    }
  }

  var body: some View {
    if viewModel.selectedView == nil {
      userViewsList
    } else {
      itemsList
    }
  }

  @ViewBuilder
  private var userViewsList: some View {
    let columns = [
      GridItem(.adaptive(minimum: 100))
    ]
    LazyVGrid(columns: columns) {
      ForEach(viewModel.userViews, id: \.id) { userView in
        UserView(name: userView.name)
          .onTapGesture {
            self.viewModel.selectUserView(userView)
          }
      }
    }
  }

  @ViewBuilder
  private var itemsList: some View {
    List(viewModel.items) { item in
      Text(item.name)
        .onAppear {
          self.viewModel.fetchMoreItemsIfNeeded(currentItem: item)
        }
    }
  }
}

#Preview("User Views") {
  let viewModel = {
    let viewModel = JellyfinLibraryViewModel()
    viewModel.userViews = [
      JellyfinLibraryViewModel.UserView(id: "0", name: "First View"),
      JellyfinLibraryViewModel.UserView(id: "1", name: "Second View"),
      JellyfinLibraryViewModel.UserView(id: "2", name: "Third View"),
      JellyfinLibraryViewModel.UserView(id: "3", name: "Fourth View"),
    ]
    viewModel.selectedView = nil
    viewModel.items = [
      JellyfinLibraryViewModel.Item(id: "0", name: "First Item"),
      JellyfinLibraryViewModel.Item(id: "1", name: "Second Item"),
    ]
    return viewModel
  }()
  JellyfinLibraryView(viewModel: viewModel)
}

#Preview("Items") {
  let viewModel = {
    let viewModel = JellyfinLibraryViewModel()
    viewModel.userViews = [
      JellyfinLibraryViewModel.UserView(id: "0", name: "First View"),
      JellyfinLibraryViewModel.UserView(id: "1", name: "Second View"),
    ]
    viewModel.selectedView = JellyfinLibraryViewModel.UserView(id: "0", name: "First View")
    viewModel.items = [
      JellyfinLibraryViewModel.Item(id: "0", name: "First Item"),
      JellyfinLibraryViewModel.Item(id: "1", name: "Second Item"),
    ]
    return viewModel
  }()
  JellyfinLibraryView(viewModel: viewModel)
}
