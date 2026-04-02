//
//  FLEXSwiftMirrorTests.swift
//  ReflexTests
//
//  Tests for FLEXSwiftMirror.swift:
//  SwiftMirror init, superMirror, isSwiftObjectOrClass
//

import XCTest
import Echo
@testable import Reflex

class FLEXSwiftMirrorTests: XCTestCase {

    var bob = Employee(name: "Bob", age: 55, position: "Programmer")

    func testAbilityToDetectSwiftTypes() {
        let nonSwiftObjects: [Any] = [
            NSObject.self, NSObject(),
            UIView.self, UIView(),
            "a string", 12345,
            self.superclass!,
        ]
        let swiftObjects: [Any] = [
            FLEXSwiftMirrorTests.self, self,
            Person.self, bob,
            [1, 2, 3], [Point(x: 1, y: 2)],
        ]

        for obj in swiftObjects  { XCTAssertTrue(isSwiftObjectOrClass(obj)) }
        for obj in nonSwiftObjects { XCTAssertFalse(isSwiftObjectOrClass(obj)) }
    }

    func testValueTypeMirrorDoesNotCrash() {
        let mirror = SwiftMirror(reflecting: Point(x: 3, y: 7))
        XCTAssertFalse(mirror.isClass)
        XCTAssertEqual(mirror.className, "Point")
        XCTAssertTrue(mirror.ivars.isEmpty)
        XCTAssertTrue(mirror.properties.isEmpty)
        XCTAssertTrue(mirror.protocols.isEmpty)
    }

    func testSuperMirror() {
        let mirror = SwiftMirror(reflecting: bob)
        let sup = mirror.superMirror
        XCTAssertNotNil(sup)
        XCTAssertEqual((sup as? SwiftMirror)?.className, NSStringFromClass(Person.self))
    }

    func testSwiftMirrorAvailable() {
        XCTAssertNotNil(NSClassFromString("FLEXSwiftMirror"))
    }

    func testSwiftMirror() {
        let slider = RFSlider(color: .red, frame: .zero)
        let sliderMirror = SwiftMirror(reflecting: slider)
        let emp = Employee(name: "Bob", age: 45, position: "Programmer", salary: 100_000)
        let employeeMirror = SwiftMirror(reflecting: emp)

        XCTAssertEqual(sliderMirror.ivars.count, 8)
        XCTAssertEqual(sliderMirror.properties.count, 1)
        XCTAssertEqual(sliderMirror.methods.count, 6)
        XCTAssertEqual(sliderMirror.protocols.count, 1)

        slider.tag = 0xAABB

        let smtag = Mirror(reflecting: slider).children.first(where: { $0.label == "tag" })!.value as! Int
        XCTAssertEqual(smtag, slider.tag)

        let tagp      = sliderMirror.ivars.first(where: { $0.name == "tag" })!
        let titlep    = sliderMirror.ivars.first(where: { $0.name == "title" })!
        let subtitlep = sliderMirror.ivars.first(where: { $0.name == "subtitle" })!
        let sizep     = employeeMirror.ivars.first(where: { $0.name == "cubicleSize" })!

        XCTAssertEqual(tagp.getValue(slider) as! Int, slider.tag)

        tagp.setValue(0xDDCC, on: slider)
        XCTAssertEqual(0xDDCC, slider.tag)
        XCTAssertEqual(tagp.getValue(slider) as! Int, slider.tag)

        XCTAssertEqual(tagp.type, .longLong)
        XCTAssertEqual(tagp.typeEncoding, "q")
        XCTAssertEqual(tagp.description, "NSInteger tag")
        XCTAssertEqual(titlep.description, "NSString title")
        XCTAssertEqual(subtitlep.description, "NSString subtitle")
        XCTAssertEqual(sizep.description, "Size cubicleSize")
    }
}
