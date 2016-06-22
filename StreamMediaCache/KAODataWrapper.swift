//
//  KAOPurgeableIndexData.swift
//  StreamMediaCache
//
//  Created by Andrii Kravchenko on 6/21/16.
//  Copyright © 2016 kievkao. All rights reserved.
//

import Foundation

class KAODataWrapper {
    private var data = NSMutableData()

    private var lengthWithPurged: Int = 0

    var length: Int { return lengthWithPurged }

    func appendData(data: NSData) {
        self.data.appendData(data)
        self.lengthWithPurged += data.length
    }

    func subdataWithRange(range: NSRange) -> NSData {

        if range.location > 30000 {

            let location = lengthWithPurged == self.data.length ? range.location : range.location - (lengthWithPurged - self.data.length)

            self.data = NSMutableData(data: self.data.subdataWithRange(NSRange(location: location, length: self.data.length - location)))

            let fixedRange = NSRange(location: 0, length: range.length)
            let requestedData = self.data.subdataWithRange(fixedRange)

            self.data = NSMutableData(data: self.data.subdataWithRange(NSRange(location: range.length, length: self.data.length - range.length)))

            return requestedData
        }
        else {
            return self.data.subdataWithRange(range)
        }
    }

    func writeToFile(path: String, options writeOptionsMask: NSDataWritingOptions) throws {
        try self.data.writeToFile(path, options: writeOptionsMask)
    }
}
