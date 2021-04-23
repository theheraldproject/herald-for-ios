//
//  FowlerBasic.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class FowlerBasic<T: DoubleValue>: Aggregate<T> {
    override var runs: Int { get { 1 }}
    private var run: Int = 1
    private let mode: Mode<T> = Mode<T>()
    private let intercept: Double
    private let coefficient: Double

    public init(intercept: Double, coefficient: Double) {
        self.intercept = intercept
        self.coefficient = coefficient
    }
    
    public override func beginRun(thisRun: Int) {
        run = thisRun
        mode.beginRun(thisRun: thisRun)
    }

    public override func map(value: Sample<T>) {
        mode.map(value: value)
    }

    public override func reduce() -> Double? {
        guard let modeValue = mode.reduce() else {
            return nil
        }
        
        let exponent = (modeValue - intercept) / coefficient
        return pow(10, exponent)
    }

    public override func reset() {
        mode.reset()
    }
}
