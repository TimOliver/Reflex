//
//  FLEXSwiftMetadatasTests.swift
//  ReflexTests
//
//  Tests for FLEXSwiftMetadatas.swift:
//  SwiftIvar (KVC, nil, properties), SwiftProtocol, structFieldNamesDict
//

import XCTest
import Echo
@testable import Reflex

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
