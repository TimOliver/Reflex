//
//  PointerExtensionsTests.swift
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

//  Tests for FLEXSwiftMirror.swift:
//  SwiftMirror init, superMirror, isSwiftObjectOrClass
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
