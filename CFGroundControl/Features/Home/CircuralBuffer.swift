//
//  CircuralBuffer.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 21/08/25.
//

import Foundation

struct CircularBuffer<T> {
    private var buffer: [T?]
    private var head = 0
    private var count = 0
    private let capacity: Int
    
    init(capacity: Int) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    mutating func append(_ element: T) {
        buffer[head] = element
        head = (head + 1) % capacity
        if count < capacity {
            count += 1
        }
    }
    
    var elements: [T] {
        let validElements = buffer.compactMap { $0 }
        let headIndex = count < capacity ? head - count : head
        
        if headIndex >= 0 {
            return Array(validElements[headIndex...]) + Array(validElements[..<headIndex])
        } else {
            return Array(validElements[(headIndex + capacity)...]) + Array(validElements[..<(headIndex + capacity)])
        }
    }
    
    mutating func removeAll() {
        head = 0
        count = 0
        buffer = Array(repeating: nil, count: capacity)
    }
}
