//
//  HardcoverBookPickerViewModel.swift
//  BookPlayer
//
//  Created by Jeremy Grenier on 6/28/25.
//  Copyright © 2025 BookPlayer LLC. All rights reserved.
//

import BookPlayerKit
import Combine
import Get
import JellyfinAPI
import SwiftUI

final class HardcoverBookPickerViewModel: HardcoverBookPickerView.Model, BPLogger {
  private let hardcoverService: HardcoverServiceProtocol

  private var disposeBag = Set<AnyCancellable>()

  private let item: SimpleLibraryItem

  init(item: SimpleLibraryItem, hardcoverService: HardcoverServiceProtocol) {
    self.item = item
    self.hardcoverService = hardcoverService

    super.init(
      loading: .fetching,
      rows: []
    )
  }

  func loadData() async {
    do {
      let result = try await hardcoverService.getBooks(for: item, perPage: 5)

      let books = result.search.results.hits.map(\.document)

      var rows = [HardcoverBookRow.Model]()
      for book in books {
        rows.append(
          .init(
            id: book.id,
            artworkURL: book.image?.url.flatMap(URL.init(string:)),
            title: book.title,
            author: book.authorNames.first ?? ""
          )
        )
      }

      Task { @MainActor in
        self.rows = rows
        self.loading = .loaded
      }
    } catch {
      Task { @MainActor in
        self.loading = .error(error.localizedDescription)
      }
    }
  }

  @MainActor
  override func onAppear() {
    self.loading = .fetching
    Task {
      await loadData()
    }
  }

  @MainActor
  override func onUnlinkTapped() {
    selected = nil
  }

  @MainActor
  override func onRowTapped(_ row: HardcoverBookRow.Model) {
    selected = row
  }
}
