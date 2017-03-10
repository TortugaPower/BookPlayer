//
//  IDZSwiftCommonCryptoTestAppTests.swift
//  IDZSwiftCommonCryptoTestAppTests
//
//  Created by idz on 9/14/15.
//  Copyright © 2015 iOSDeveloperZone.com. All rights reserved.
//

import XCTest
import IDZSwiftCommonCrypto
@testable import IDZSwiftCommonCryptoTestApp

class IDZSwiftCommonCryptoTestAppTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: - Crypto Demo
    func test_StreamCryptor_AES_ECB() {
        let key = arrayFrom(hexString: "2b7e151628aed2a6abf7158809cf4f3c")
        let plainText = arrayFrom(hexString: "6bc1bee22e409f96e93d7e117393172a")
        let expectedCipherText = arrayFrom(hexString: "3ad77bb40d7a3660a89ecaf32466ef97")
        
        let aesEncrypt = StreamCryptor(operation:.encrypt, algorithm:.aes, options:.ECBMode, key:key, iv:Array<UInt8>())
        var cipherText : [UInt8] = []
        var dataOut = Array<UInt8>(repeating:UInt8(0), count:plainText.count)
        let (byteCount, _) = aesEncrypt.update(byteArrayIn: plainText, byteArrayOut: &dataOut)
    
        
        cipherText += dataOut[0..<Int(byteCount)]
        //(byteCount, status) = aesEncrypt.final(&dataOut)
        //assert(byteCount == 0, "Final byte count is 0")
        assert(expectedCipherText.count == cipherText.count , "Counts are as expected")
        assert(expectedCipherText == cipherText, "Obtained expected cipher text")
    }
    
}
