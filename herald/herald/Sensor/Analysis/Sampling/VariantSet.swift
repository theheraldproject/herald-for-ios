//
//  VariantSet.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class VariantSet {
    private let defaultListSize: Int
    private var map: [ValueType:ListManager] = [:]
    
    public init(_ defaultListSize: Int) {
        self.defaultListSize = defaultListSize
    }
    
    public func variants() -> Set<ValueType> {
        return Set<String>(map.keys)
    }
    
    public func sampledIDs() -> Set<SampledID> {
        var sampledIDs: Set<SampledID> = Set<SampledID>()
        map.values.forEach({ sampledIDs.formUnion($0.sampledIDs()) })
        return sampledIDs
    }
    
    public func add(variant: ValueType, listSize: Int) -> ListManager {
        let listManager = ListManager(listSize)
        let typeName = String(describing: variant)
        map[typeName] = listManager
        return listManager
    }
    
    public func remove(variant: ValueType) {
        let typeName = String(describing: variant)
        map.removeValue(forKey: typeName)
    }
    
    public func remove<T:DoubleValue>(_ type: T.Type) {
        remove(variant: ValueType(describing: type))
    }
    
    public func remove(sampledID: SampledID) {
        map.values.forEach({ $0.remove(sampledID) })
    }
    
    public func removeAll() {
        map.removeAll()
    }
    
    public func listManager(variant: ValueType) -> ListManager {
        let typeName = String(describing: variant)
        if let listManager = map[typeName] {
            return listManager
        } else {
            return add(variant: variant, listSize: defaultListSize)
        }
    }
    
    public func listManager<T:DoubleValue>(_ type: T.Type) -> ListManager {
        return listManager(variant: ValueType(describing: type))
    }
    
    public func listManager(variant: ValueType, listFor: SampledID) -> SampleList {
        return listManager(variant: variant).list(listFor)
    }
    
    public func listManager<T:DoubleValue>(_ type: T.Type, _ listFor: SampledID) -> SampleList {
        return listManager(variant: ValueType(describing: type), listFor: listFor)
    }

    public func size() -> Int {
        return map.count
    }
    
    public func push(_ sampledID: SampledID, _ sample: Sample) {
        listManager(variant: sample.valueType).push(sampledID, sample)
    }
}
