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
    var MaxStoredSizeBytes = 52428800   // 50M

    var length: Int { return lengthWithPurged }

    func appendData(data: NSData) {
        self.data.append(data as Data)
        self.lengthWithPurged += data.length
    }

    func subdataWithRange(range: NSRange) -> NSData {

        if range.location > MaxStoredSizeBytes {

            let adjustedLocation = range.location - (lengthWithPurged - self.data.length)

            self.data = NSMutableData(data: self.data.subdata(with: NSRange(location: adjustedLocation, length: self.data.length - adjustedLocation)))

            let requestedData = self.data.subdata(with: NSRange(location: 0, length: range.length))

            self.data = NSMutableData(data: self.data.subdata(with: NSRange(location: range.length, length: self.data.length - range.length)))

            return requestedData as NSData
        }
        else {
            return self.data.subdata(with: range) as NSData
        }
    }

    func writeToFile(path: String, options writeOptionsMask: NSData.WritingOptions) throws {
        try self.data.write(toFile: path, options: writeOptionsMask)
    }
}
