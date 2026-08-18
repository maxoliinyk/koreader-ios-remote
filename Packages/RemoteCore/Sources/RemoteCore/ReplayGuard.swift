//
//  ReplayGuard.swift
//  KOReaderRemote
//
//  Created by Max Oliinyk on 18.08.26.
//

import Foundation

public struct ReplayGuard: Sendable {
    private let capacity: Int
    private var order: [String] = []
    private var values: Set<String> = []

    public init(capacity: Int = 128) {
        self.capacity = max(1, capacity)
    }

    @discardableResult
    public mutating func insert(_ nonce: String) -> Bool {
        guard !values.contains(nonce) else { return false }
        values.insert(nonce)
        order.append(nonce)
        if order.count > capacity {
            values.remove(order.removeFirst())
        }
        return true
    }
}
