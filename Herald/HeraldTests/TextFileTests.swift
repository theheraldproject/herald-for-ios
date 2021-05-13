//
//  TextFileTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class TextFileTests: XCTestCase {

    func testEmpty() {
        let textFile = TextFile(filename: "empty.txt")
        XCTAssertTrue(textFile.empty())
        XCTAssertEqual(textFile.contentsOf(), "")
    }

    func testWriteOneLine() {
        let textFile = TextFile(filename: "oneLine.txt")
        textFile.overwrite("")
        textFile.write("line1")
        XCTAssertFalse(textFile.empty())
        XCTAssertEqual(textFile.contentsOf(), "line1\n")
    }

    func testWriteTwoLines() {
        let textFile = TextFile(filename: "twoLine.txt")
        textFile.overwrite("")
        textFile.write("line1")
        textFile.write("line2")
        XCTAssertFalse(textFile.empty())
        XCTAssertEqual(textFile.contentsOf(), "line1\nline2\n")
    }

    func testOverwrite() {
        let textFile = TextFile(filename: "overwrite.txt")
        textFile.overwrite("")
        XCTAssertTrue(textFile.empty())
        textFile.overwrite("line1")
        XCTAssertEqual(textFile.contentsOf(), "line1")
        textFile.overwrite("line2")
        XCTAssertEqual(textFile.contentsOf(), "line2")
    }
}
