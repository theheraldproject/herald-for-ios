//
//  TransportLayerSecurity.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public protocol TransportLayerSecurity {
    
    func getPublicKey() -> KeyExchangePublicKey
    
    
}
