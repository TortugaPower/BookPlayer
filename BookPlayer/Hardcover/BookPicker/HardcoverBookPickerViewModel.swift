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
  private var books: [HardcoverBookRow.Model] = []

  private var searchTask: Task<Void, Never>?

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
      await processSearchResults(result)
    } catch {
      Task { @MainActor in
        self.loading = .error(error.localizedDescription)
      }
    }
  }

  @MainActor
  override func onSearch(_ query: String) {
    searchTask?.cancel()

    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      rows = books
      return
    }

    loading = .fetching

    searchTask = Task {
      try? await Task.sleep(for: .milliseconds(500))
      guard !Task.isCancelled else { return }

      do {
        let result = try await hardcoverService.searchBooks(query: query, perPage: 10)
        await processSearchResults(result)
      } catch {
        Task { @MainActor in
          self.loading = .error(error.localizedDescription)
        }
      }
    }
  }
  
  private func processSearchResults(_ result: BooksData) async {
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

    if self.books.isEmpty {
      self.books = rows
    }

    Task { @MainActor in
      self.rows = rows
      self.loading = .loaded
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
