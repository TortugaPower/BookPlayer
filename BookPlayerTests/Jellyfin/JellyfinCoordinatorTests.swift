//
//  JellyfinCoordinatorTests.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-22.
//  Copyright © 2024 BookPlayer LLC. All rights reserved.
//

@testable import BookPlayer
import BookPlayerKit
import JellyfinAPI
import SwiftUI
import XCTest

class JellyfinCoordinatorInitialStateTests: XCTestCase {
  var mockFlow: MockCoordinatorPresentationFlow!
  var mockSingleFileDownloadService: SingleFileDownloadService!
  var mockKeychainService: KeychainServiceMock!
  var mockJellyfinConnectionService: JellyfinConnectionService!
  var sut: JellyfinCoordinator!
  
  override func setUp() {
    mockFlow = MockCoordinatorPresentationFlow()
    
    mockSingleFileDownloadService = SingleFileDownloadService(networkClient: NetworkClientMock(mockedResponse: Empty.value))
    
    mockKeychainService = KeychainServiceMock()
    mockJellyfinConnectionService = JellyfinConnectionService(keychainService: mockKeychainService)
    
    sut = JellyfinCoordinator(
      flow: mockFlow,
      singleFileDownloadService: mockSingleFileDownloadService,
      connectionService: mockJellyfinConnectionService
    )
  }
  
  func testInitialStateShowsConnectionViewWhenLoggedOut() {
    XCTAssertNil(mockJellyfinConnectionService.connection)
    sut.start()
    XCTAssertEqual(mockFlow.horizontalStack, ["UIHostingController<JellyfinConnectionView>"])
  }
  
  @MainActor
  func testShowLibraryWhenSignInFinishes() throws {
    sut.start()
    XCTAssertEqual(mockFlow.horizontalStack, ["UIHostingController<JellyfinConnectionView>"])
    guard let connectionVC = mockFlow.navigationController.viewControllers.first as? UIHostingController<JellyfinConnectionView> else {
      XCTAssert(false, "Requires connection VC to proceed")
      return
    }
    let connectionViewModel = connectionVC.rootView.viewModel
    
    connectionViewModel.form.serverUrl = "http://example.com"
    connectionViewModel.form.serverName = "Mock Server"
    connectionViewModel.form.username = "test"
    connectionViewModel.form.password = "secret"
    connectionViewModel.connectionState = .connected

//    (url: URL(string: "http://example.com")!, userID: "42", userName: "test", accessToken: "super secret", serverName: "Mock Server", saveToKeychain: true)
    connectionViewModel.onTransition?(.showLibrary)

    XCTAssertNotNil(mockJellyfinConnectionService.connection)
    do {
      let savedConnectionData: JellyfinConnectionData? = try mockKeychainService.get(.jellyfinConnection)
      XCTAssertEqual(savedConnectionData?.url, URL(string: "http://example.com")!)
    }
    
    XCTAssertEqual(mockFlow.horizontalStack, [
      "UIHostingController<JellyfinConnectionView>",
      "UIHostingController<JellyfinLibraryView<JellyfinLibraryViewModel>>",
    ])
    
    guard let libraryVC = mockFlow.navigationController.viewControllers.last as? UIHostingController<JellyfinLibraryView<JellyfinLibraryViewModel>> else {
      XCTAssert(false, "Requires library VC to proceed")
      return
    }
    let libraryViewModel = libraryVC.rootView.viewModel
    
    XCTAssertEqual(libraryViewModel.data, .topLevel(libraryName: "Mock Server"))
  }
}
