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

    var length: Int { return self.data.length }

    func appendData(data: NSData) {
        self.data.appendData(data)
    }

    func subdataWithRange(range: NSRange) -> NSData {
        return self.data.subdataWithRange(range)
    }

    func writeToFile(path: String, options writeOptionsMask: NSDataWritingOptions) throws {
        try self.data.writeToFile(path, options: writeOptionsMask)
    }
}
