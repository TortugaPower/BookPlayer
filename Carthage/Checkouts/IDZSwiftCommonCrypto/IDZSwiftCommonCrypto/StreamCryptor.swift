//
//  Cryptor.swift
//  SwiftCommonCrypto
//
//  Created by idz on 9/19/14.
//  Copyright (c) 2014 iOS Developer Zone. All rights reserved.
//

import Foundation
import CommonCrypto

/**
    Encrypts or decrypts return results as they become available.

    - note: The underlying cipher may be a block or a stream cipher.

    Use for large files or network streams.

    For small, in-memory buffers Cryptor may be easier to use.
*/
open class StreamCryptor
{
    ///
    /// Enumerates Cryptor operations
    ///
    public enum Operation
    {
        /// Encrypting
        case encrypt,
        /// Decrypting
        decrypt
        
        /// Convert to native `CCOperation`
        func nativeValue() -> CCOperation {
            switch self {
            case .encrypt : return CCOperation(kCCEncrypt)
            case .decrypt : return CCOperation(kCCDecrypt)
            }
        }
    }
    
    public enum ValidKeySize {
        case fixed(Int)
        case discrete([Int])
        case range(Int,Int)
        
        /**
            Determines if a given `keySize` is valid for this algorithm.
        */
        func isValid(keySize: Int) -> Bool {
            switch self {
            case .fixed(let fixed): return (fixed == keySize)
            case .range(let min, let max): return ((keySize >= min) && (keySize <= max))
            case .discrete(let values): return values.contains(keySize)
            }
        }
        
        /**
            Determines the next valid key size; that is, the first valid key size larger 
            than the given value.
            Will return `nil` if the passed in `keySize` is greater than the max.
        */
        func padded(keySize: Int) -> Int? {
            switch self {
            case .fixed(let fixed):
                return (keySize <= fixed) ? fixed : nil
            case .range(let min, let max):
                return (keySize > max) ? nil : ((keySize < min) ? min : keySize)
            case .discrete(let values):
                return values.sorted().reduce(nil) { answer, current in
                    return answer ?? ((current >= keySize) ? current : nil)
                }
            }
        }
        
        
    }
	
	///
	/// Enumerates encryption mode
	///
	public enum Mode
	{
		case ECB
		case CBC
		case CFB
		case CTR
		case F8	//		= 5, // Unimplemented for now (not included)
		case LRW//		= 6, // Unimplemented for now (not included)
		case OFB
		case XTS
		case RC4
		case CFB8
		
		func nativeValue() -> CCMode {
			switch self {
			case .ECB : return CCMode(kCCModeECB)
			case .CBC : return CCMode(kCCModeCBC)
			case .CFB : return CCMode(kCCModeCFB)
			case .CTR : return CCMode(kCCModeCTR)
			case .F8 : return CCMode(kCCModeF8)// Unimplemented for now (not included)
			case .LRW : return CCMode(kCCModeLRW)// Unimplemented for now (not included)
			case .OFB : return CCMode(kCCModeOFB)
			case .XTS : return CCMode(kCCModeXTS)
			case .RC4 : return CCMode(kCCModeRC4)
			case .CFB8 : return CCMode(kCCModeCFB8)
			}
		}
	}
	
	/**
	 Enumerated encryption paddings
	 See: https://en.wikipedia.org/wiki/Block_cipher_mode_of_operation#Padding
	*/
	public enum Padding
	{
		/// No Padding -> Use only when you messages have correct block size.
		case NoPadding
		
		/// PKCS7 Padding
		case PKCS7Padding
		
		func nativeValue() -> CCPadding {
			switch self {
			case .NoPadding : return CCPadding(ccNoPadding)
			case .PKCS7Padding : return CCPadding(ccPKCS7Padding)
			}
		}
	}
	
    ///
    /// Enumerates available algorithms
    ///
    public enum Algorithm
    {
        /// Advanced Encryption Standard
        case aes,
        /// Data Encryption Standard
        des,
        /// Triple DES
        tripleDES,
        /// CAST
        cast,
        /// RC2
        rc2,
        /// Blowfish
        blowfish
        
        /// Blocksize, in bytes, of algorithm.
        public func blockSize() -> Int {
            switch self {
            case .aes : return kCCBlockSizeAES128
            case .des : return kCCBlockSizeDES
            case .tripleDES : return kCCBlockSize3DES
            case .cast : return kCCBlockSizeCAST
            case .rc2: return kCCBlockSizeRC2
            case .blowfish : return kCCBlockSizeBlowfish
            }
        }
        /// Native, CommonCrypto constant for algorithm.
        func nativeValue() -> CCAlgorithm
        {
            switch self {
            case .aes : return CCAlgorithm(kCCAlgorithmAES)
            case .des : return CCAlgorithm(kCCAlgorithmDES)
            case .tripleDES : return CCAlgorithm(kCCAlgorithm3DES)
            case .cast : return CCAlgorithm(kCCAlgorithmCAST)
            case .rc2: return CCAlgorithm(kCCAlgorithmRC2)
            case .blowfish : return CCAlgorithm(kCCAlgorithmBlowfish)
            }
        }
        
        /// Determines the valid key size for this algorithm
        func validKeySize() -> ValidKeySize {
            switch self {
            case .aes : return .discrete([kCCKeySizeAES128, kCCKeySizeAES192, kCCKeySizeAES256])
            case .des : return .fixed(kCCKeySizeDES)
            case .tripleDES : return .fixed(kCCKeySize3DES)
            case .cast : return .range(kCCKeySizeMinCAST, kCCKeySizeMaxCAST)
            case .rc2: return .range(kCCKeySizeMinRC2, kCCKeySizeMaxRC2)
            case .blowfish : return .range(kCCKeySizeMinBlowfish, kCCKeySizeMaxBlowfish)
            }
        }
        
        /// Tests if a given keySize is valid for this algorithm
        func isValid(keySize: Int) -> Bool {
            return self.validKeySize().isValid(keySize: keySize)
        }
        
        /// Calculates the next, if any, valid keySize greater or equal to a given `keySize` for this algorithm
        func padded(keySize: Int) -> Int? {
            return self.validKeySize().padded(keySize: keySize)
        }
    }
    
    /*
    * It turns out to be rather tedious to reprent ORable
    * bitmask style options in Swift. I would love to
    * to say that I was smart enough to figure out the
    * magic incantions below for myself, but it was, in fact,
    * NSHipster
    * From: http://nshipster.com/rawoptionsettype/
    */
    ///
    /// Maps CommonCryptoOptions onto a Swift struct.
    ///
    public struct Options : OptionSet {
        public typealias RawValue = Int
        public let rawValue: RawValue
        
        /// Convert from a native value (i.e. `0`, `kCCOptionPKCS7Padding`, `kCCOptionECBMode`)
        public init(rawValue: RawValue) {
            self.rawValue = rawValue
        }
        
        /// Convert from a native value (i.e. `0`, `kCCOptionPKCS7Padding`, `kCCOptionECBMode`)
        public init(_ rawValue: RawValue) {
            self.init(rawValue: rawValue)
        }
        
        /// No options
        public static let None = Options(rawValue: 0)
        /// Use padding. Needed unless the input is a integral number of blocks long.
        public static var PKCS7Padding =  Options(rawValue:kCCOptionPKCS7Padding)
        /// Electronic Code Book Mode. Don't use this.
        public static var ECBMode = Options(rawValue:kCCOptionECBMode)
    }
    

    
    /**
        The status code resulting from the last method call to this Cryptor.
        Used to get additional information when optional chaining collapes.
    */
    open var status : Status = .success

    //MARK: - High-level interface
    /**
        Creates a new StreamCryptor
    
        - parameter operation: the operation to perform see Operation (Encrypt, Decrypt)
        - parameter algorithm: the algorithm to use see Algorithm (AES, DES, TripleDES, CAST, RC2, Blowfish)
        - parameter key: a byte array containing key data
        - parameter iv: a byte array containing initialization vector
    */
    public convenience init(operation: Operation, algorithm: Algorithm, options: Options, key: [UInt8], iv : [UInt8])
    {
        guard let paddedKeySize = algorithm.padded(keySize:key.count) else {
            fatalError("FATAL_ERROR: Invalid key size")
        }
        
        self.init(operation:operation, algorithm:algorithm, options:options, keyBuffer:zeroPad(array: key, blockSize: paddedKeySize), keyByteCount:paddedKeySize, ivBuffer:iv)
    }
    /**
        Creates a new StreamCryptor
        
        - parameter operation: the operation to perform see Operation (Encrypt, Decrypt)
        - parameter algorithm: the algorithm to use see Algorithm (AES, DES, TripleDES, CAST, RC2, Blowfish)
        - parameter key: a string containing key data (will be interpreted as UTF8)
        - parameter iv: a string containing initialization vector data (will be interpreted as UTF8)
    */
    public convenience init(operation: Operation, algorithm: Algorithm, options: Options, key: String, iv : String)
    {
        let keySize = key.utf8.count
        guard let paddedKeySize = algorithm.padded(keySize: keySize) else {
            fatalError("FATAL_ERROR: Invalid key size")
        }
        
        self.init(operation:operation, algorithm:algorithm, options:options, keyBuffer:zeroPad(string: key, blockSize: paddedKeySize), keyByteCount:paddedKeySize, ivBuffer:iv)
    }
	/**
	Creates a new StreamCryptor
	
	- parameter operation: the operation to perform see Operation (Encrypt, Decrypt)
	- parameter algorithm: the algorithm to use see Algorithm (AES, DES, TripleDES, CAST, RC2, Blowfish)
	- parameter mode: the mode used by algorithm see Mode (ECB, CBC, CFB, CTR, F8, LRW, OFB, XTS, RC4, CFB8)
	- parameter padding: the padding to use. When using NoPadding: each block of UPDATE must be correct size
	- parameter key: a byte array containing key data
	- parameter iv: a byte array containing initialization vector
	
	*/
	public convenience init(operation: Operation, algorithm: Algorithm, mode: Mode, padding: Padding, key: [UInt8], iv : [UInt8]) {
        
        guard algorithm.isValid(keySize: key.count) else  { fatalError("FATAL_ERROR: Invalid key size.") }

		
		self.init(operation: operation, algorithm: algorithm, mode: mode, padding: padding, keyBuffer: key, keyByteCount: key.count, ivBuffer: iv)
	}
	/**
	Creates a new StreamCryptor
	
	- parameter operation: the operation to perform see Operation (Encrypt, Decrypt)
	- parameter algorithm: the algorithm to use see Algorithm (AES, DES, TripleDES, CAST, RC2, Blowfish)
	- parameter mode: the mode used by algorithm see Mode (ECB, CBC, CFB, CTR, F8, LRW, OFB, XTS, RC4, CFB8)
	- parameter padding: the padding to use. When using NoPadding: each block of UPDATE must be correct size
	- parameter key: a string containing key data (will be interpreted as UTF8)
	- parameter iv: a string containing initialization vector data (will be interpreted as UTF8)
	
	*/
	public convenience init(operation: Operation, algorithm: Algorithm, mode: Mode, padding: Padding, key: String, iv: String) {
		let keySize = key.utf8.count
        guard let paddedKeySize = algorithm.padded(keySize: keySize) else {
			fatalError("FATAL_ERROR: Invalid key size")
		}
		
        self.init(operation:operation, algorithm:algorithm, mode: mode, padding: padding, keyBuffer:zeroPad(string: key, blockSize: paddedKeySize), keyByteCount: paddedKeySize, ivBuffer: iv)
	}
    /**
        Add the contents of an Objective-C NSData buffer to the current encryption/decryption operation.
        
        - parameter dataIn: the input data
        - parameter byteArrayOut: output data
        - returns: a tuple containing the number of output bytes produced and the status (see Status)
    */
    open func update(dataIn: Data, byteArrayOut: inout [UInt8]) -> (Int, Status)
    {
        let dataOutAvailable = byteArrayOut.count
        var dataOutMoved = 0
        update(bufferIn: (dataIn as NSData).bytes, byteCountIn: dataIn.count, bufferOut: &byteArrayOut, byteCapacityOut: dataOutAvailable, byteCountOut: &dataOutMoved)
        return (dataOutMoved, self.status)
    }
    /**
        Add the contents of a Swift byte array to the current encryption/decryption operation.

        - parameter byteArrayIn: the input data
        - parameter byteArrayOut: output data
        - returns: a tuple containing the number of output bytes produced and the status (see Status)
    */
    open func update(byteArrayIn: [UInt8], byteArrayOut: inout [UInt8]) -> (Int, Status)
    {
        let dataOutAvailable = byteArrayOut.count
        var dataOutMoved = 0
        update(bufferIn: byteArrayIn, byteCountIn: byteArrayIn.count, bufferOut: &byteArrayOut, byteCapacityOut: dataOutAvailable, byteCountOut: &dataOutMoved)
        return (dataOutMoved, self.status)
    }
    /**
        Add the contents of a string (interpreted as UTF8) to the current encryption/decryption operation.

        - parameter byteArrayIn: the input data
        - parameter byteArrayOut: output data
        - returns: a tuple containing the number of output bytes produced and the status (see Status)
    */
    open func update(stringIn: String, byteArrayOut: inout [UInt8]) -> (Int, Status)
    {
        let dataOutAvailable = byteArrayOut.count
        var dataOutMoved = 0
        update(bufferIn: stringIn, byteCountIn: stringIn.lengthOfBytes(using: String.Encoding.utf8), bufferOut: &byteArrayOut, byteCapacityOut: dataOutAvailable, byteCountOut: &dataOutMoved)
        return (dataOutMoved, self.status)
    }
    /**
        Retrieves all remaining encrypted or decrypted data from this cryptor.

        :note: If the underlying algorithm is an block cipher and the padding option has
        not been specified and the cumulative input to the cryptor has not been an integral
        multiple of the block length this will fail with an alignment error.

        :note: This method updates the status property

        - parameter byteArrayOut: the output bffer        
        - returns: a tuple containing the number of output bytes produced and the status (see Status)
    */
    open func final(byteArrayOut: inout [UInt8]) -> (Int, Status)
    {
        let dataOutAvailable = byteArrayOut.count
        var dataOutMoved = 0
        _ = final(bufferOut: &byteArrayOut, byteCapacityOut: dataOutAvailable, byteCountOut: &dataOutMoved)
        return (dataOutMoved, self.status)
    }
    
    // MARK: - Low-level interface
    /**
        - parameter operation: the operation to perform see Operation (Encrypt, Decrypt)
        - parameter algorithm: the algorithm to use see Algorithm (AES, DES, TripleDES, CAST, RC2, Blowfish)
        - parameter keyBuffer: pointer to key buffer
        - parameter keyByteCount: number of bytes in the key
        - parameter ivBuffer: initialization vector buffer
    */
    public init(operation: Operation, algorithm: Algorithm, options: Options, keyBuffer: UnsafeRawPointer,
        keyByteCount: Int, ivBuffer: UnsafeRawPointer)
    {
        guard algorithm.isValid(keySize: keyByteCount) else  { fatalError("FATAL_ERROR: Invalid key size.") }

        let rawStatus = CCCryptorCreate(operation.nativeValue(), algorithm.nativeValue(), CCOptions(options.rawValue), keyBuffer, keyByteCount, ivBuffer, context)
        if let status = Status.fromRaw(status: rawStatus)
        {
            self.status = status
        }
        else
        {
            print("FATAL_ERROR: CCCryptorCreate returned unexpected status (\(rawStatus)).")
            fatalError("CCCryptorCreate returned unexpected status.")
        }
    }
	/**
	- parameter operation: the operation to perform see Operation (Encrypt, Decrypt)
	- parameter algorithm: the algorithm to use see Algorithm (AES, DES, TripleDES, CAST, RC2, Blowfish)
	- parameter mode: the mode used by algorithm see Mode (ECB, CBC, CFB, CTR, F8, LRW, OFB, XTS, RC4, CFB8)
	- parameter padding: the padding to use. When using NoPadding: each block of UPDATE must be correct size
	- parameter keyBuffer: pointer to key buffer
	- parameter keyByteCount: number of bytes in the key
	- parameter ivBuffer: initialization vector buffer
	
	*/
	public init(operation: Operation, algorithm: Algorithm, mode: Mode, padding: Padding, keyBuffer: UnsafeRawPointer, keyByteCount: Int, ivBuffer: UnsafeRawPointer) {
		
        guard algorithm.isValid(keySize: keyByteCount) else  { fatalError("FATAL_ERROR: Invalid key size.") }
		
		let rawStatus = CCCryptorCreateWithMode(operation.nativeValue(), mode.nativeValue(), algorithm.nativeValue(), padding.nativeValue(), ivBuffer, keyBuffer, keyByteCount, nil, 0, 0, 0, context)
		if let status = Status.fromRaw(status: rawStatus)
		{
			self.status = status
		}
		else
		{
			NSLog("FATAL_ERROR: CCCryptorCreateWithMode returned unexpected status (\(rawStatus)).")
			fatalError("CCCryptorCreateWithMode returned unexpected status.")
		}

	}
    /**
        - parameter bufferIn: pointer to input buffer
        - parameter inByteCount: number of bytes contained in input buffer 
        - parameter bufferOut: pointer to output buffer
        - parameter outByteCapacity: capacity of the output buffer in bytes
        - parameter outByteCount: on successful completion, the number of bytes written to the output buffer
        - returns: 
    */
    @discardableResult open func update(bufferIn: UnsafeRawPointer, byteCountIn: Int, bufferOut: UnsafeMutableRawPointer, byteCapacityOut: Int, byteCountOut: inout Int) -> Status
    {
        if(self.status == Status.success)
        {
            let rawStatus = CCCryptorUpdate(context.pointee, bufferIn, byteCountIn, bufferOut, byteCapacityOut, &byteCountOut)
            if let status = Status.fromRaw(status: rawStatus)
            {
                self.status =  status

            }
            else
            {
                print("FATAL_ERROR: CCCryptorUpdate returned unexpected status (\(rawStatus)).")
                fatalError("CCCryptorUpdate returned unexpected status.")
            }
        }
        return self.status
    }
    /**
        Retrieves all remaining encrypted or decrypted data from this cryptor.
        
        :note: If the underlying algorithm is an block cipher and the padding option has
        not been specified and the cumulative input to the cryptor has not been an integral 
        multiple of the block length this will fail with an alignment error.
    
        :note: This method updates the status property
        
        - parameter bufferOut: pointer to output buffer
        - parameter outByteCapacity: capacity of the output buffer in bytes
        - parameter outByteCount: on successful completion, the number of bytes written to the output buffer
    */
    @discardableResult open func final(bufferOut: UnsafeMutableRawPointer, byteCapacityOut: Int, byteCountOut: inout Int) -> Status
    {
        if(self.status == Status.success)
        {
            let rawStatus = CCCryptorFinal(context.pointee, bufferOut, byteCapacityOut, &byteCountOut)
            if let status = Status.fromRaw(status:rawStatus)
            {
                self.status =  status
            }
            else
            {
                print("FATAL_ERROR: CCCryptorFinal returned unexpected status (\(rawStatus)).")
                fatalError("CCCryptorUpdate returned unexpected status.")
            }
        }
        return self.status
    }
    /**
        Determines the number of bytes that wil be output by this Cryptor if inputBytes of additional
        data is input.
        
        - parameter inputByteCount: number of bytes that will be input.
        - parameter isFinal: true if buffer to be input will be the last input buffer, false otherwise.
    */
    open func getOutputLength(inputByteCount: Int, isFinal: Bool = false) -> Int
    {
        return CCCryptorGetOutputLength(context.pointee, inputByteCount, isFinal)
    }
    
    deinit
    {
        let rawStatus = CCCryptorRelease(context.pointee)
        if let status = Status.fromRaw(status: rawStatus)
        {
            if(status != .success)
            {
                print("WARNING: CCCryptoRelease failed with status \(rawStatus).")
            }
        }
        else
        {
            print("FATAL_ERROR: CCCryptorUpdate returned unexpected status (\(rawStatus)).")
            fatalError("CCCryptorUpdate returned unexpected status.")
        }
        context.deallocate(capacity: 1)
    }
    
    fileprivate var context = UnsafeMutablePointer<CCCryptorRef?>.allocate(capacity: 1)
    
}
