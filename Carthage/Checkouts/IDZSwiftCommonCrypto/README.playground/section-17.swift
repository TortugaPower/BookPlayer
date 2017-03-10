let keys6 = PBKDF.deriveKey("password", salt: arrayFromString("salt"), prf: .SHA1, rounds: 1, derivedKeyLength: 20)
// RFC 6070 - Should derive 0c60c80f961f0e71f3a9b524af6012062fe037a6
let expectedRFC6070 = arrayFromHexString("0c60c80f961f0e71f3a9b524af6012062fe037a6")
assert(keys6 == expectedRFC6070)
