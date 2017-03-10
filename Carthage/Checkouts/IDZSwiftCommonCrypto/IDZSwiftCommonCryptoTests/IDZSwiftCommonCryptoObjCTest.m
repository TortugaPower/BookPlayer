//
//  IDZSwiftCommonCryptoObjCTest.m
//  IDZSwiftCommonCrypto
//
//  Created by idz on 9/30/14.
//  Copyright (c) 2014 iOSDeveloperZone.com. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>


@import IDZSwiftCommonCrypto;


@interface IDZSwiftCommonCryptoObjCTest : XCTestCase

@end

@implementation IDZSwiftCommonCryptoObjCTest

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

+ (NSData*)dataFromHexString:(NSString*)hexString
{
    NSAssert(hexString.length % 2 == 0, @"string contains even number of characters");
    NSMutableData *data = [[NSMutableData alloc] initWithCapacity:hexString.length/2];
    NSAssert(data, @"allocated data");
    for(NSInteger i = 0; i < hexString.length; i += 2)
    {
        UInt8 byte;
        NSScanner *scanner = [[NSScanner alloc] initWithString:[hexString substringWithRange:NSMakeRange(i,2)]];
        unsigned int ui;
        [scanner scanHexInt:&ui];
        byte = (UInt8)ui;
        [data appendBytes:&byte length:sizeof(byte)];
    }
    return data;
}

- (void)testExample {
    // This is an example of a functional test case.
    XCTAssert(YES, @"Pass");
    
}

- (void)testDataFromHexString {
    NSString *s = @"deadface";
    UInt8 bytes[] = { 0xde, 0xad, 0xfa, 0xce };
    NSData *expected = [NSData dataWithBytes:bytes length:sizeof(bytes)];
    NSData *obtained = [self.class dataFromHexString:s];
    XCTAssertEqualObjects(obtained, expected, @"PASS");
    
}

- (void)testHmac_SHA1_ObjC
{
    NSData* key = [self.class dataFromHexString:@"0102030405060708090a0b0c0d0e0f10111213141516171819"];
    NSData *expected = [self.class dataFromHexString:@"4c9007f4026250c6bc8414f9bf50c86c2d7235da"];

    HMAC *hmac = [[HMAC alloc] initWithAlgorithm:kCCHmacAlgSHA1 key:key];
    
    
}
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
