//
//  KeyDerivation.swift
//  SwiftCommonCrypto
//
//  Created by idz on 9/19/14.
//  Copyright (c) 2014 iOS Developer Zone. All rights reserved.
//

import Foundation
import CommonCrypto

///
/// Derives key material from a password or passphrase.
///
open class PBKDF
{
    /// Enumerates available pseudo random algorithms
    public enum PseudoRandomAlgorithm
    {
        /// Secure Hash Algorithm 1
        case sha1
        /// Secure Hash Algorithm 2 224-bit
        case sha224
        /// Secure Hash Algorithm 2 256-bit
        case sha256
        /// Secure Hash Algorithm 2 384-bit
        case sha384
        /// Secure Hash Algorithm 2 512-bit
        case sha512
        
        func nativeValue() -> CCPseudoRandomAlgorithm
        {
            switch self {
                case .sha1: return CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1)
                case .sha224: return CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA224)
                case .sha256: return CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256)
                case .sha384: return CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA384)
                case .sha512: return CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512)
                
            }
        }
    }
    
    ///
    /// Determines the (approximate) number of iterations of the key derivation algorithm that need
    /// to be run to achieve a particular delay (or calculation time).
    ///
    /// - parameter passwordLength: password length in bytes
    /// - parameter saltLength: salt length in bytes
    /// - parameter algorithm: the PseudoRandomAlgorithm to use
    /// - parameter derivedKeyLength: the desired key length
    /// - parameter msec: the desired calculation time
    /// - returns: the number of times the algorithm should be run
    ///
    open class func calibrate(passwordLength: Int, saltLength: Int, algorithm: PseudoRandomAlgorithm, derivedKeyLength: Int, msec : UInt32) -> UInt
    {
        return UInt(CCCalibratePBKDF(CCPBKDFAlgorithm(kCCPBKDF2), passwordLength, saltLength, algorithm.nativeValue(), derivedKeyLength, msec))
    }
    

    /// 
    /// Derives key material from a password and salt.
    ///
    /// -parameter password: the password string, will be converted using UTF8
    /// -parameter salt: the salt string will be converted using UTF8
    /// -parameter prf: the pseudo random function
    /// -parameter round: the number of rounds
    /// -parameter derivedKeyLength: the length of the desired derived key, in bytes.
    /// -returns: the derived key
    ///
    open class func deriveKey(password: String, salt: String, prf: PseudoRandomAlgorithm, rounds: uint, derivedKeyLength: UInt) -> [UInt8]
    {
        var derivedKey = Array<UInt8>(repeating: 0, count: Int(derivedKeyLength))
        let status : Int32 = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), password, password.lengthOfBytes(using: String.Encoding.utf8), salt, salt.lengthOfBytes(using: String.Encoding.utf8), prf.nativeValue(), rounds, &derivedKey, derivedKey.count)
        if(status != Int32(kCCSuccess))
        {
            print("ERROR: CCKeyDerivationPBDK failed with stats \(status).")
            fatalError("ERROR: CCKeyDerivationPBDK failed.")
        }
        return derivedKey
    }
    
    ///
    /// Derives key material from a password and salt.
    ///
    /// -parameter password: the password string, will be converted using UTF8
    /// -parameter salt: the salt array of bytes
    /// -parameter prf: the pseudo random function
    /// -parameter round: the number of rounds
    /// -parameter derivedKeyLength: the length of the desired derived key, in bytes.
    /// -returns: the derived key
    ///
    open class func deriveKey(password: String, salt: [UInt8], prf: PseudoRandomAlgorithm, rounds: uint, derivedKeyLength: UInt) -> [UInt8]
    {
        var derivedKey = Array<UInt8>(repeating: 0, count: Int(derivedKeyLength))
        let status : Int32 = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), password, password.lengthOfBytes(using: String.Encoding.utf8), salt, salt.count, prf.nativeValue(), rounds, &derivedKey, derivedKey.count)
        if(status != Int32(kCCSuccess))
        {
            print("ERROR: CCKeyDerivationPBDK failed with stats \(status).")
            fatalError("ERROR: CCKeyDerivationPBDK failed.")
        }
        return derivedKey
    }
    
    //MARK: - Low-level Routines
    ///
    /// Derives key material from a password buffer.
    ///
    /// - parameter password: pointer to the password buffer
    /// - parameter passwordLength: password length in bytes
    /// - parameter salt: pointer to the salt buffer
    /// - parameter saltLength: salt length in bytes
    /// - parameter prf: the PseudoRandomAlgorithm to use
    /// - parameter rounds: the number of rounds of the algorithm to use
    /// - parameter derivedKey: pointer to the derived key buffer.
    /// - parameter derivedKeyLength: the desired key length
    /// - return: the number of times the algorithm should be run
    ///
    open class func deriveKey(password: UnsafePointer<Int8>, passwordLen: Int, salt: UnsafePointer<UInt8>, saltLen: Int, prf: PseudoRandomAlgorithm, rounds: uint, derivedKey: UnsafeMutablePointer<UInt8>, derivedKeyLen: Int)
    {
        let status : Int32 = CCKeyDerivationPBKDF(CCPBKDFAlgorithm(kCCPBKDF2), password, passwordLen, salt, saltLen, prf.nativeValue(), rounds, derivedKey, derivedKeyLen)
        if(status != Int32(kCCSuccess))
        {
            print("ERROR: CCKeyDerivationPBDK failed with stats \(status).")
            fatalError("ERROR: CCKeyDerivationPBDK failed.")
        }
    }
}
