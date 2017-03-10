//
//  Random.swift
//  SwiftCommonCrypto
//
//  Created by idz on 9/19/14.
//  Copyright (c) 2014 iOS Developer Zone. All rights reserved.
//
// https://opensource.apple.com/source/CommonCrypto/CommonCrypto-60061/lib/CommonRandom.c

import Foundation
import CommonCrypto

public typealias RNGStatus = Status

///
/// Generates buffers of random bytes.
///
open class Random
{
    /**
    Wraps native CCRandomeGenerateBytes call.
    
    :note: CCRNGStatus is typealiased to CCStatus but this routine can only return kCCSuccess or kCCRNGFailure
    
    - parameter bytes: a pointer to the buffer that will receive the bytes
    - return: .Success or .RNGFailure as appropriate.
    
     */
    open class func generateBytes(bytes: UnsafeMutableRawPointer, byteCount: Int ) -> RNGStatus
    {
        let statusCode = CCRandomGenerateBytes(bytes, byteCount)
        guard let status = Status(rawValue: statusCode) else {
            fatalError("CCRandomGenerateBytes returned unexpected status code: \(statusCode)")
        }
        return status
    }
    /**
    Generates an array of random bytes.
    
    - parameter bytesCount: number of random bytes to generate
    - return: an array of random bytes
    - throws: an `RNGStatus` on failure
    */
    open class func generateBytes(byteCount: Int ) throws -> [UInt8]
    {
        guard byteCount > 0 else { throw RNGStatus.paramError }
        
        var bytes : [UInt8] = Array(repeating: UInt8(0), count: byteCount)
        let status = generateBytes(bytes: &bytes, byteCount: byteCount)
        
        guard status == .success else { throw status }
        return bytes
    }
    
    /**
     A version of generateBytes that always throws an error.
    
     Use it to test that code handles this.
    
    - parameter bytesCount: number of random bytes to generate
    - return: an array of random bytes
     */
    open class func generateBytesThrow(byteCount: Int ) throws -> [UInt8]
    {
        if(byteCount <= 0)
        {
            fatalError("generateBytes: byteCount must be positve and non-zero")
        }
        var bytes : [UInt8] = Array(repeating: UInt8(0), count: byteCount)
        let status = generateBytes(bytes: &bytes, byteCount: byteCount)
        throw status
        //return bytes
    }
}
