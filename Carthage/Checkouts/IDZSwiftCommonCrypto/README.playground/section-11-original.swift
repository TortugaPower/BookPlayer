var keys5 = arrayFromHexString("0102030405060708090a0b0c0d0e0f10111213141516171819")
var datas5 : [UInt8] = Array(count:50, repeatedValue:0xcd)
var expecteds5 = arrayFromHexString("4c9007f4026250c6bc8414f9bf50c86c2d7235da")
var hmacs5 = HMAC(algorithm:.SHA1, key:keys5).update(datas5)?.final()

// RFC2202 says this should be 4c9007f4026250c6bc8414f9bf50c86c2d7235da
let expectedRFC2202 = arrayFromHexString("4c9007f4026250c6bc8414f9bf50c86c2d7235da")
assert(hmacs5! == expectedRFC2202)