let  s = "The quick brown fox jumps over the lazy dog."
var md5s2 : Digest = Digest(algorithm:.MD5)
md5s2.update(s)
let digests2 = md5s2.final()

// According to Wikipedia this should be
// e4d909c290d0fb1ca068ffaddf22cbd0
hexStringFromArray(digests2)
assert(digests2 == arrayFromHexString("e4d909c290d0fb1ca068ffaddf22cbd0"))
