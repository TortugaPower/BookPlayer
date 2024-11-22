//
//  JellyfinConnectionServiceTests.swift
//  BookPlayer
//
//  Created by Lysann Tranvouez on 2024-11-22.
//  Copyright © 2024 Tortuga Power. All rights reserved.
//

@testable import BookPlayer
import BookPlayerKit
import XCTest
import Combine

class JellyfinConnectionServiceTests: XCTestCase {
  var mockKeychain: KeychainServiceMock!
  var sut: JellyfinConnectionService!
  
  override func setUp() {
    mockKeychain = KeychainServiceMock()
    sut = JellyfinConnectionService(keychainService: mockKeychain)
  }
  
  func makeMockConnectionData(serverUrlString: String = "http://example.com", accessToken: String = "12345") -> JellyfinConnectionData {
    return JellyfinConnectionData(url: URL(string: serverUrlString)!,
                                  serverName: "Mock Server",
                                  userID: "42",
                                  userName: "Mock User",
                                  accessToken: accessToken)
  }
  
  func testNoConnectionByDefault() throws {
    XCTAssertNil(try mockKeychain.get<JellyfinConnectionData>(.jellyfinConnection))
    XCTAssertNil(sut.connection)
  }
  
  func testNewInstanceLoadsSavedConnection() throws {
    do {
      let connectionData = makeMockConnectionData()
      try mockKeychain.set(connectionData, key: .jellyfinConnection)
    }
    
    let newInstance = JellyfinConnectionService(keychainService: mockKeychain)
    
    XCTAssertNotNil(newInstance.connection)
    XCTAssertEqual(newInstance.connection?.url, URL(string: "http://example.com")!)
    XCTAssertEqual(newInstance.connection?.serverName, "Mock Server")
    XCTAssertEqual(newInstance.connection?.userID, "42")
    XCTAssertEqual(newInstance.connection?.userName, "Mock User")
    XCTAssertEqual(newInstance.connection?.accessToken, "12345")
  }
  
  func testSetAndGetConnection() {
    XCTAssertNil(sut.connection)
    
    sut.setConnection(makeMockConnectionData(), saveToKeychain: false)
    
    XCTAssertNotNil(sut.connection)
    XCTAssertEqual(sut.connection?.url, URL(string: "http://example.com")!)
    
    sut.setConnection(makeMockConnectionData(serverUrlString: "http://example.com:8096"), saveToKeychain: false)
    
    XCTAssertNotNil(sut.connection)
    XCTAssertEqual(sut.connection?.url, URL(string: "http://example.com:8096")!)
  }
  
  func testSaveInvalidConnection() {
    sut.setConnection(makeMockConnectionData(accessToken: ""), saveToKeychain: false)
    XCTAssertNil(sut.connection)
  }
  
  func testDontSaveToKeychain() throws {
    do {
      let dataInKeychain: JellyfinConnectionData? = try mockKeychain.get(.jellyfinConnection)
      XCTAssertNil(dataInKeychain)
    }
    XCTAssertNil(sut.connection)
    sut.setConnection(makeMockConnectionData(), saveToKeychain: false)
    
    do {
      let dataInKeychain: JellyfinConnectionData? = try mockKeychain.get(.jellyfinConnection)
      XCTAssertNil(dataInKeychain)
    }
    
    let newInstance = JellyfinConnectionService(keychainService: mockKeychain)
    XCTAssertNil(newInstance.connection)
  }
  
  func testSaveToKeychainAndGetWithNewInstance() throws {
    XCTAssertNil(sut.connection)
    sut.setConnection(makeMockConnectionData(), saveToKeychain: true)
    
    do {
      let dataInKeychain: JellyfinConnectionData? = try mockKeychain.get(.jellyfinConnection)
      XCTAssertNotNil(dataInKeychain)
    }
    
    let newInstance = JellyfinConnectionService(keychainService: mockKeychain)
    XCTAssertNotNil(newInstance.connection)
    XCTAssertEqual(newInstance.connection?.url, URL(string: "http://example.com")!)
  }
  
  func testDeleteConnection() {
    sut.setConnection(makeMockConnectionData(), saveToKeychain: true)
    XCTAssertNotNil(sut.connection)
    var newInstance = JellyfinConnectionService(keychainService: mockKeychain)
    XCTAssertNotNil(newInstance.connection)
    
    sut.deleteConnection()
    XCTAssertNil(sut.connection)
    newInstance = JellyfinConnectionService(keychainService: mockKeychain)
    XCTAssertNil(newInstance.connection)
  }
  
  func testConnectionPublishesChanges() throws {
    var eventsPublished = 0
    var latestConnectionDataInEvent: JellyfinConnectionData?
    
    var disposeBag = Set<AnyCancellable>()
    sut.$connection.dropFirst().sink { newConnection in
      eventsPublished += 1
      latestConnectionDataInEvent = newConnection
    }
    .store(in: &disposeBag)
    
    sut.setConnection(makeMockConnectionData(), saveToKeychain: false)
    
    XCTAssertEqual(eventsPublished, 1)
    XCTAssertNotNil(latestConnectionDataInEvent)
    XCTAssertEqual(latestConnectionDataInEvent?.url, URL(string: "http://example.com")!)
    
    sut.setConnection(makeMockConnectionData(serverUrlString: "http://example.com:8096"), saveToKeychain: false)
    
    XCTAssertEqual(eventsPublished, 2)
    XCTAssertNotNil(latestConnectionDataInEvent)
    XCTAssertEqual(latestConnectionDataInEvent?.url, URL(string: "http://example.com:8096")!)
    
    sut.deleteConnection()
    
    XCTAssertEqual(eventsPublished, 3)
    XCTAssertNil(latestConnectionDataInEvent)
    
    sut.setConnection(makeMockConnectionData(), saveToKeychain: true)
    
    XCTAssertEqual(eventsPublished, 4)
    XCTAssertNotNil(latestConnectionDataInEvent)
    XCTAssertEqual(latestConnectionDataInEvent?.url, URL(string: "http://example.com")!)
  }
  
  func testCreateClientStatic() {
    var client = JellyfinConnectionService.createClient(serverUrlString: "http://example.com")
    XCTAssertNotNil(client)
    XCTAssertEqual(client?.configuration.url, URL(string: "http://example.com")!)
    XCTAssertNil(client?.accessToken)
    
    client = JellyfinConnectionService.createClient(serverUrlString: "http://example.com", accessToken: "12345")
    XCTAssertNotNil(client)
    XCTAssertEqual(client?.configuration.url, URL(string: "http://example.com")!)
    XCTAssertEqual(client?.accessToken, "12345")
    
    client = JellyfinConnectionService.createClient(serverUrlString: "")
    XCTAssertNil(client)
    
    client = JellyfinConnectionService.createClient(for: makeMockConnectionData())
    XCTAssertEqual(client?.configuration.url, URL(string: "http://example.com")!)
    XCTAssertEqual(client?.accessToken, "12345")
  }
  
  func testCreateClientFromSavedConnection() {
    XCTAssertNil(sut.createClient())
    
    sut.setConnection(makeMockConnectionData(), saveToKeychain: false)
    let client = sut.createClient()
    XCTAssertNotNil(client)
    XCTAssertEqual(client?.configuration.url, URL(string: "http://example.com")!)
    XCTAssertEqual(client?.accessToken, "12345")
    
    sut.deleteConnection()
    XCTAssertNil(sut.createClient())
  }
}
