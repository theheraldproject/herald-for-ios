//
//  RingBuffer.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class RingBuffer<T> {
    private var data: [T?]
    private var oldestPosition, newestPosition: Int
    public var description: String { get {
        guard size() > 0 else {
            return "[]"
        }
        var s: String = "["
        for i in 0...size()-1 {
            guard let item = get(i) else {
                continue
            }
            if s.count > 1 {
                s += " ,"
            }
            s += String(describing: item)
        }
        s += "]"
        return s
    }}
    
    public init(_ size: Int) {
        self.data = [T?](repeating: nil, count: size)
        self.oldestPosition = size
        self.newestPosition = size
    }
    
    public func push(_ item: T) {
        incrementNewest()
        data[newestPosition] = item
    }
    
    public func size() -> Int {
        if newestPosition == data.count {
            return 0
        }
        if newestPosition >= oldestPosition {
            // not overlapping the end
            return newestPosition - oldestPosition + 1
        }
        // we've overlapped
        return (1 + newestPosition) + (data.count - oldestPosition)
    }
    
    public func get(_ index: Int) -> T? {
        if newestPosition >= oldestPosition {
            guard let item = data[index + oldestPosition] else {
                return nil
            }
            return item
        }
        if index + oldestPosition >= data.count {
            // TODO handle the situation where this pos > newestPosition (i.e. gap in the middle)
            guard let item = data[index + oldestPosition - data.count] else {
                return nil
            }
            return item
        }
        guard let item = data[index + oldestPosition] else {
            return nil
        }
        return item
    }

    public func clear() {
        oldestPosition = data.count
        newestPosition = data.count
    }

    public func latest() -> T? {
        guard newestPosition != data.count, let item = data[newestPosition] else {
            return nil
        }
        return item
    }
    
    private func incrementNewest() {
        if newestPosition == data.count {
            newestPosition = 0
            oldestPosition = 0
        } else {
            if newestPosition == (oldestPosition - 1) {
                oldestPosition += 1
                if oldestPosition == data.count {
                    oldestPosition = 0
                }
            }
            newestPosition += 1
        }
        if newestPosition == data.count {
            // just gone past the end of the container
            newestPosition = 0;
            if oldestPosition == 0 {
                // erases oldest if not already removed
                oldestPosition += 1
            }
        }
    }
}
