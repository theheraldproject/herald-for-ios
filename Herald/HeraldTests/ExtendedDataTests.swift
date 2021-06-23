//
//  ExtendedDataTests.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class ExtendedDataTests: XCTestCase {

    func testMultipleSections() throws {
        let extendedData = ConcreteExtendedDataV1();

        let section1Code = UInt8(0x01);
        let section1Value = UInt8(3);
        extendedData.addSection(code: section1Code, value: section1Value)
        
        let section2Code = UInt8(0x02);
        let section2Value = UInt16(25);
        extendedData.addSection(code: section2Code, value: section2Value)
        
        XCTAssertEqual(2, extendedData.getSections().count)
    }

}
