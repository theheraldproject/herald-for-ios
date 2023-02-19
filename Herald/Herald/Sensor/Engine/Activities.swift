//
//  Activities.swift
//
//  Copyright 2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//
//  Created by Adam Fowler on 07/02/2023.
//

import Foundation

public typealias FeatureTag = Data

public let HeraldBluetoothProtocolConnection: FeatureTag = FeatureTag(repeating: UInt8(0x01), count: 1)

public typealias Priority = UInt8

public let CriticalPriority: Priority = Priority(200)
public let HighPriority: Priority = Priority(150)
public let DefaultPriority: Priority = Priority(100)
public let LowPriority: Priority = Priority(50)

public class Prerequisite {
    private var feature: FeatureTag
    private var relatedTo: TargetIdentifier? = nil
    
    init(required: FeatureTag) {
        feature = required
    }
    
    init(required: FeatureTag, toward: TargetIdentifier) {
        feature = required
        relatedTo = toward
    }
    
    func getRelatedTo() -> TargetIdentifier? {
        return relatedTo
    }
    
    func getFeature() -> FeatureTag {
        return feature
    }
}

public class PrioritisedPrerequisite: Prerequisite {
    private var priority: Priority = DefaultPriority

    override init(required: FeatureTag) {
        super.init(required: required)
    }
    
    override init(required: FeatureTag, toward: TargetIdentifier) {
        super.init(required: required, toward: toward)
    }
    
    init(required: FeatureTag, priority: Priority) {
        super.init(required: required)
        self.priority = priority
    }
    
    init(required: FeatureTag, toward: TargetIdentifier, priority: Priority) {
        super.init(required: required, toward: toward)
        self.priority = priority
    }
}

public struct ActivityDescription {
    var priority: Priority
    var name: String
    var prerequisities: [Prerequisite]
}
    

public protocol ActivityProvider {
    func executeActivity(activity: ActivityDescription)
}

public struct Activity {
    var description: ActivityDescription
    var executor: ActivityProvider
}

public protocol CoordinationProvider {
    func connectionsProvided() -> [FeatureTag]
    func provision(prereqs: [PrioritisedPrerequisite]) -> [PrioritisedPrerequisite]
    func requiredConnections() -> [PrioritisedPrerequisite]
    func requiredActivities() -> [Activity]
}
