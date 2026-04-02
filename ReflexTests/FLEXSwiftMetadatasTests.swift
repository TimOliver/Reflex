//
//  FLEXSwiftMetadatasTests.swift
//
//  Copyright (c) Flipboard, Inc. (2014–2016); Tanner Bennett (2021-2026)
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification,
//  are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice, this
//  list of conditions and the following disclaimer in the documentation and/or
//  other materials provided with the distribution.
//
//  * Neither the name of Flipboard nor the names of its
//  contributors may be used to endorse or promote products derived from
//  this software without specific prior written permission.
//
//  * You must NOT include this project in an application to be submitted
//  to the App Store™, as this project uses too many private APIs.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
//  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
//  WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
//  ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
//  (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
//  ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
//  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import XCTest
import Echo
@testable import Reflex

//  Tests for FLEXSwiftMetadatas.swift:
//  SwiftIvar (KVC, nil, properties), SwiftProtocol, structFieldNamesDict
class FLEXSwiftMetadatasTests: XCTestCase {

    var bob = Employee(name: "Bob", age: 55, position: "Programmer")

    // MARK: - SwiftIvar

    func testBoolTypeEncoding() {
        let mirror = SwiftMirror(reflecting: BoolHolder())
        let flagIvar = mirror.ivars.first(where: { $0.name == "flag" })!
        XCTAssertEqual(flagIvar.type, .cBool)
        XCTAssertEqual(flagIvar.typeEncoding, "B")
    }

    func testBoolKVC() {
        let holder = BoolHolder()
        let mirror = SwiftMirror(reflecting: holder)
        let flagIvar = mirror.ivars.first(where: { $0.name == "flag" })!

        XCTAssertEqual(flagIvar.getValue(holder) as? Bool, false)
        flagIvar.setValue(true, on: holder)
        XCTAssertEqual(holder.flag, true)
        XCTAssertEqual(flagIvar.getValue(holder) as? Bool, true)
    }

    func testSetOptionalToNil() {
        let holder = BoolHolder()
        let mirror = SwiftMirror(reflecting: holder)
        let optIvar = mirror.ivars.first(where: { $0.name == "optionalCount" })!

        optIvar.setValue(42, on: holder)
        XCTAssertEqual(holder.optionalCount, 42)

        // Previously crashed: Optional<T> has kind .optional, not .enum
        optIvar.setValue(nil, on: holder)
        XCTAssertNil(holder.optionalCount)
    }

    func testSetClassOptionalToNil() {
        let holder = HolderWithRef()
        let mirror = SwiftMirror(reflecting: holder)
        let ivar = mirror.ivars.first(where: { $0.name == "value" })!

        ivar.setValue(bob, on: holder)
        XCTAssertNotNil(holder.value)

        ivar.setValue(nil, on: holder)
        XCTAssertNil(holder.value)
    }

    func testSwiftIvarProperties() {
        // Use a field declared directly on Employee (not inherited from Person)
        let mirror = SwiftMirror(reflecting: bob)
        let positionIvar = mirror.ivars.first(where: { $0.name == "position" })!

        XCTAssertGreaterThan(positionIvar.offset, 0)
        XCTAssertGreaterThan(positionIvar.size, 0)
        XCTAssertNotNil(positionIvar.imagePath)
        XCTAssertFalse(positionIvar.details.isEmpty)
        XCTAssertEqual(positionIvar.getPotentiallyUnboxedValue(bob) as? String, "Programmer")
    }

    // MARK: - structFieldNamesDict

    func testStructFieldLabels() {
        let mirror = SwiftMirror(reflecting: Sprite.self)
        let structIvar = mirror.ivars.first(where: { $0.name == "boundingBox" })!

        guard let labels = structIvar.auxiliaryInfo(forKey: FLEXAuxiliarynfoKeyFieldLabels) as? [String: [String]] else {
            XCTFail("Expected [String: [String]]"); return
        }
        XCTAssertEqual(labels.count, 3)
        XCTAssertEqual(labels["{Rect={Point=qq}{Size=qq}}"], ["Point origin", "Size size"])
        XCTAssertEqual(labels["{Point=qq}"], ["Int x", "Int y"])
        XCTAssertEqual(labels["{Size=qq}"], ["Int width", "Int height"])
    }

    func testStructFieldLabelsDeepRecursion() {
        // Path → Segment → Point is three levels deep.
        // The old code only walked one level, missing Point.
        let mirror = SwiftMirror(reflecting: PathHolder())
        let pathIvar = mirror.ivars.first(where: { $0.name == "path" })!

        guard let labels = pathIvar.auxiliaryInfo(forKey: FLEXAuxiliarynfoKeyFieldLabels) as? [String: [String]] else {
            XCTFail("Expected [String: [String]]"); return
        }
        XCTAssertEqual(labels.count, 3)
        XCTAssertEqual(labels["{Point=qq}"], ["Int x", "Int y"])
    }

    // MARK: - SwiftProtocol

    func testSwiftProtocolName() {
        let mirror = SwiftMirror(reflecting: RFSlider(color: .red, frame: .zero))
        let p = mirror.protocols.compactMap { $0 as? SwiftProtocol }
            .first(where: { $0.name == "Slidable" })
        XCTAssertNotNil(p)
    }

    func testSwiftProtocolInheritedProtocols() {
        let mirror = SwiftMirror(reflecting: NamedThing())
        let fullyNamed = mirror.protocols.compactMap { $0 as? SwiftProtocol }
            .first(where: { $0.name == "FullyNamed" })
        XCTAssertNotNil(fullyNamed)
        XCTAssertEqual(fullyNamed?.protocols.count, 1)
        XCTAssertEqual(fullyNamed?.protocols.first?.name, "Named")
    }

    func testSwiftProtocolProperties() {
        let mirror = SwiftMirror(reflecting: RFSlider(color: .red, frame: .zero))
        let p = mirror.protocols.compactMap { $0 as? SwiftProtocol }
            .first(where: { $0.name == "Slidable" })!

        _ = p.objc_protocol
        _ = p.imagePath
        _ = p.requiredMethods
        _ = p.optionalMethods
        _ = p.requiredProperties
        _ = p.optionalProperties
    }
}
