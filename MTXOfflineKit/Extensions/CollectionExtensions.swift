//
//  CollectionExtensions.swift
//  APPSOfflineKit
//
//  Created by Ken Grigsby on 2/7/17.
//  Copyright © 2017 Appstronomy. All rights reserved.
//

public extension Collection {
    
    /// Returns an array of arrays of n non-overlapping elements of self
    /// - Parameter n: The size of the chunk
    /// - Precondition: `n > 0`
    /// - SeeAlso: `func window(n: Int) -> [[Self.Generator.Element]]`
    ///  ```swift
    ///  [1, 2, 3, 4, 5].chunk(by: 2)
    ///
    ///  [[1, 2], [3, 4], [5]]
    /// ```
    public func chunked(by n: IndexDistance) -> [SubSequence] {
        var res: [SubSequence] = []
        var i = startIndex
        var j: Index
        while i != endIndex {
            j = index(i, offsetBy: n, limitedBy: endIndex) ?? endIndex
            res.append(self[i..<j])
            i = j
        }
        return res
    }
    
}
