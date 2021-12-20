//
//  Array+Blocks.swift
//  MegaKit
//
//  Created by Florin Pop on 22.07.21.
//

import Foundation

public extension Array {
    // https://www.hackingwithswift.com/example-code/language/how-to-split-an-array-into-chunks
    func blocks(of size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }

    func padded(to length: Int, padding: Element) -> [Element] {
        if count >= length {
            return self
        }
        return self + Array(repeating: padding, count: length - count)
    }
}
