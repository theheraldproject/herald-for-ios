//
//  VariantSet.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class VariantSet {
    private let defaultListSize: Int
    private var map: [String:ListManager<DoubleValue>] = [:]
    
    public init(_ defaultListSize: Int) {
        self.defaultListSize = defaultListSize
    }
    
    public func variants() -> Set<String> {
        return Set<String>(map.keys)
    }
    
    public func sampledIDs() -> Set<SampledID> {
        var sampledIDs: Set<SampledID> = Set<SampledID>()
        map.values.forEach({ sampledIDs.formUnion($0.sampledIDs()) })
        return sampledIDs
    }
    
    public func add<T:DoubleValue>(variant: T.Type, listSize: Int) -> ListManager<DoubleValue> {
        let listManager = ListManager<DoubleValue>(listSize)
        let typeName = String(describing: variant)
        map[typeName] = listManager
        return listManager
    }
    
    public func remove<T:DoubleValue>(variant: T.Type) {
        let typeName = String(describing: variant)
        map.removeValue(forKey: typeName)
    }
    
    public func remove(sampledID: SampledID) {
        map.values.forEach({ $0.remove(sampledID) })
    }
    
    public func listManager<T:DoubleValue>(variant: T.Type) -> ListManager<DoubleValue> {
        let typeName = String(describing: variant)
        if let listManager = map[typeName] {
            return listManager
        } else {
            return add(variant: variant, listSize: defaultListSize)
        }
    }
    
    public func push<T:DoubleValue>(sampledID: SampledID, sample: Sample<T>) {
        //listManager(variant: sample.valueType).push(sampledID, sample)
    }
}
//
//    public <T extends DoubleValue> SampleList<T> listManager(final Class<T> variant, final SampledID listFor) {
//        final ListManager<T> listManager = listManager(variant);
//        return listManager.list(listFor);
//    }
//
//    public int size() {
//        return map.size();
//    }
//
//    public <T extends DoubleValue> void push(final SampledID sampledID, final Sample<T> sample) {
//        ((ListManager<T>) listManager(sample.value().getClass())).push(sampledID, sample);
//    }
//}
