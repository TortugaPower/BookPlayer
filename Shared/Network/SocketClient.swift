//
//  SocketClient.swift
//  BookPlayer
//
//  Created by Yamil Nuñez Aguirre on 13/8/22.
//  Copyright © 2022 Tortuga Power. All rights reserved.
//

import Foundation
import SocketIO

public protocol SocketClientProtocol {
	func connectSocket() throws
	func disconnectSocket() throws
	func sendCustomEvent(eventName: String, jsonString: String) throws
}

public enum SocketEvent: String {
	case TRACK_UPDATE = "track_update"
}

public class SocketClient: SocketClientProtocol, BPLogger {
	var socket: SocketIOClient? = nil
	let manager: SocketManager?
	let keychain: KeychainServiceProtocol

	public init(keychain: KeychainServiceProtocol = KeychainService()) {
		self.keychain = keychain
		let serverURL: String = Bundle.main.configurationValue(for: .socketServerURL)
		print("server url \(serverURL)")
		self.manager = SocketManager(socketURL: URL(string: serverURL)!, config: [.log(false), .compress])
		self.socket = self.manager?.defaultSocket
		self.setupSocketEvents()
	}
	
	public func connectSocket() throws {
		if let accessToken = try? keychain.getAccessToken() {
			self.socket?.connect(withPayload: ["authorization": accessToken])
			print("connectSocket \(accessToken)")
		}
	}
	
	public func disconnectSocket() throws {
		self.socket?.removeAllHandlers()
		self.socket?.disconnect()
	}
	
	
	func setupSocketEvents() {
		self.socket?.on(clientEvent: .connect) {data, ack in
			Self.logger.trace("[Socketclient] connected")
		}
		self.socket?.on("lastPlayedItem") {data, ack in
			guard let lastPlayedItem = data[0] as? SyncedItem else { return }
			print("lastPlayedItem \(lastPlayedItem)")
			ack.with("Got your ack", "dude")
		}
	}
	
	public func sendCustomEvent(eventName: String, jsonString: String) throws {
		print(eventName);
		self.socket?.emit(eventName, ["data": jsonString])
	}
}
