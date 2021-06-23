//
//  ListManager.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class ListManager {
    private let queue = DispatchQueue(label: "Sensor.Analysis.Sampling.ListManager")
    private let listSize: Int
    private var map: [SampledID:SampleList] = [:]
    
    public init(_ listSize: Int) {
        self.listSize = listSize
    }
    
    public func list(_ listFor: SampledID) -> SampleList {
        queue.sync {
            if let list = map[listFor] {
                return list
            } else {
                let list = SampleList(listSize)
                map[listFor] = list
                return list
            }
        }
    }
    
    public func sampledIDs() -> Set<SampledID> {
        queue.sync {
            return Set<SampledID>(map.keys)
        }
    }
    
    public func remove(_ listFor: SampledID) {
        queue.sync {
            let _ = map.removeValue(forKey: listFor)
        }
    }
    
    public func size() -> Int {
        queue.sync {
            return map.count
        }
    }
    
    public func clear() {
        queue.sync {
            map.removeAll()
        }
    }
    
    public func push(_ sampledID: SampledID, _ sample: Sample) {
        list(sampledID).push(sample: sample)
    }
}
