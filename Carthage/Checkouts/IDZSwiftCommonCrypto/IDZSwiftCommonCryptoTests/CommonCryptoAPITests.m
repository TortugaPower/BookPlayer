//
//  CommonCryptoAPITests.m
//  IDZSwiftCommonCrypto
//
//  Created by idz on 9/14/15.
//  Copyright © 2015 iOSDeveloperZone.com. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <CommonCrypto/CommonCrypto.h>

@interface CommonCryptoAPITests : XCTestCase

@end

void LogHexArray(const char* pMessage, uint8_t* pBuffer, size_t nBytesInBuffer)
{
    NSMutableString *s = [NSMutableString stringWithFormat:@"%s: ", pMessage];
    for(size_t i = 0; i < nBytesInBuffer; ++i)
    {
        [s appendFormat:@"%02x ", pBuffer[i]];
    }
    NSLog(@"%@", s);
}

@implementation CommonCryptoAPITests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

#define LENGTH(_a) sizeof((_a))/sizeof((_a)[0])

/**
 * Here to track down differences between iOS 8 and iOS 9
 */
- (void)testExample {
    uint8_t key[] = { 0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c };
    uint8_t plainText[] =  { 0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a };
    uint8_t expectedCipherText[] = {0x3a, 0xd7, 0x7b, 0xb4, 0x0d, 0x7a, 0x36, 0x60, 0xa8, 0x9e, 0xca, 0xf3, 0x24, 0x66, 0xef, 0x97 };
    uint8_t cipherText[LENGTH(expectedCipherText)];
    CCCryptorRef cryptor;
    
    CCCryptorStatus status = CCCryptorCreate(kCCEncrypt, kCCAlgorithmAES, 0, key, LENGTH(key), nil, &cryptor);
    XCTAssert(status == kCCSuccess);
    size_t bytesOut = 0;
    status = CCCryptorUpdate(cryptor, plainText, LENGTH(plainText), cipherText, LENGTH(cipherText), &bytesOut);
    LogHexArray("cipherText", cipherText, bytesOut);
    XCTAssert(status == kCCSuccess);
    XCTAssert(bytesOut == LENGTH(expectedCipherText));
    XCTAssert(memcmp(cipherText, expectedCipherText, LENGTH(expectedCipherText)) == 0);
    // This should produce no output
    status = CCCryptorFinal(cryptor, cipherText, LENGTH(cipherText), &bytesOut);
    XCTAssert(status == kCCSuccess);
    if(bytesOut != 0) {
        LogHexArray("cipherText", cipherText, bytesOut);
    }
    XCTAssert(bytesOut == 0);
    
    
    
}


@end
