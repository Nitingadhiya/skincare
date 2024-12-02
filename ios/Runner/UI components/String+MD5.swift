//
//  String+MD5.swift
//  PerfectLibDemo
//
//  Created by Alex Lin on 2019/5/9.
//  Copyright © 2019 Perfect Corp. All rights reserved.
//

extension String {
    func md5() -> String {
        let str = self.cString(using: .utf8)
        let strLen = CUnsignedInt(self.lengthOfBytes(using: .utf8))
        let digestLen = Int(CC_MD5_DIGEST_LENGTH)
        let result = UnsafeMutablePointer<CUnsignedChar>.allocate(capacity: digestLen)
        CC_MD5(str!, strLen, result)
        var hash = String.init()
        for i in 0 ..< digestLen {
            hash = hash.appendingFormat("%02x", result[i])
        }
        result.deinitialize(count: digestLen)
        return String(format: hash as String)
    }
}
