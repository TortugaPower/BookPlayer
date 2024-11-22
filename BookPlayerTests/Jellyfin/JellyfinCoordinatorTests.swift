//
//  JellyfinCoordinatorTests.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-22.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

@testable import BookPlayer
import BookPlayerKit
import JellyfinAPI
import SwiftUI
import XCTest

class JellyfinCoordinatorInitialStateTests: XCTestCase {
  var presentingController: MockNavigationController!
  var mockKeychainService: KeychainServiceMock!
  var mockJellyfinConnectionService: JellyfinConnectionService!
  var sut: JellyfinCoordinator!
  
  override func setUp() {
    presentingController = MockNavigationController()
    
    let mockSingleFileDownloadService = SingleFileDownloadService(networkClient: NetworkClientMock(mockedResponse: Empty.value))
    mockKeychainService = KeychainServiceMock()
    mockJellyfinConnectionService = JellyfinConnectionService(keychainService: mockKeychainService)
    sut = JellyfinCoordinator(flow: .pushFlow(navigationController: presentingController),
                              singleFileDownloadService: mockSingleFileDownloadService,
                              jellyfinConnectionService: mockJellyfinConnectionService)
  }
  
  func testInitialStateShowsConnectionViewWhenLoggedOut() {
    XCTAssertNil(mockJellyfinConnectionService.connection)
    sut.start()
    XCTAssertEqual(presentingController.horizontalStack, ["UIHostingController<JellyfinConnectionView>"])
  }
  
  func testInitialStateShowsConnectionAndLibraryViewWhenLoggedIn() {
    mockJellyfinConnectionService.setConnection(JellyfinConnectionServiceTests.makeMockConnectionData(), saveToKeychain: false)
    sut.start()
    XCTAssertEqual(presentingController.horizontalStack, [
      "UIHostingController<JellyfinConnectionView>",
      "UIHostingController<JellyfinLibraryView<JellyfinLibraryViewModel>>",
    ])
  }
  
  @MainActor
  func testShowLibraryWhenSignInFinishes() throws {
    sut.start()
    XCTAssertEqual(presentingController.horizontalStack, ["UIHostingController<JellyfinConnectionView>"])
    guard let connectionVC = presentingController.viewControllers.first as? UIHostingController<JellyfinConnectionView> else {
      XCTAssert(false, "Requires connection VC to proceed")
      return
    }
    let connectionViewModel = connectionVC.rootView.viewModel
    
    connectionViewModel.form.serverUrl = "http://example.com"
    connectionViewModel.form.serverName = "Mock Server"
    connectionViewModel.form.username = "test"
    connectionViewModel.form.password = "secret"
    connectionViewModel.form.rememberMe = true
    connectionViewModel.connectionState = .connected

    connectionViewModel.onTransition?(.signInFinished(url: URL(string: "http://example.com")!, userID: "42", accessToken: "super secret"))
    
    XCTAssertNotNil(mockJellyfinConnectionService.connection)
    do {
      let savedConnectionData: JellyfinConnectionData? = try mockKeychainService.get(.jellyfinConnection)
      XCTAssertEqual(savedConnectionData?.url, URL(string: "http://example.com")!)
    }
    
    XCTAssertEqual(presentingController.horizontalStack, [
      "UIHostingController<JellyfinConnectionView>",
      "UIHostingController<JellyfinLibraryView<JellyfinLibraryViewModel>>",
    ])
    
    guard let libraryVC = presentingController.viewControllers.last as? UIHostingController<JellyfinLibraryView<JellyfinLibraryViewModel>> else {
      XCTAssert(false, "Requires library VC to proceed")
      return
    }
    let libraryViewModel = libraryVC.rootView.viewModel
    
    XCTAssertEqual(libraryViewModel.data, .topLevel(libraryName: "Mock Server", userID: "42"))
  }
}
