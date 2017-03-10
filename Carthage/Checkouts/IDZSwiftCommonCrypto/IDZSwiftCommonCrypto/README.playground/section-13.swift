var key = arrayFromHexString("2b7e151628aed2a6abf7158809cf4f3c")
var plainText = "The quick brown fox jumps over the lazy dog. The fox has more or less had it at this point."

var cryptor = Cryptor(operation:.Encrypt, algorithm:.AES, options:.PKCS7Padding, key:key, iv:Array<UInt8>())
var cipherText = cryptor.update(plainText)?.final()

cryptor = Cryptor(operation:.Decrypt, algorithm:.AES, options:.PKCS7Padding, key:key, iv:Array<UInt8>())
var decryptedPlainText = cryptor.update(cipherText!)?.final()
var decryptedString = decryptedPlainText!.reduce("") { $0 + String(UnicodeScalar($1)) }
decryptedString
assert(decryptedString == plainText)