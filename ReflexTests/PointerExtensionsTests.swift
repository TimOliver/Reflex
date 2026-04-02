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

//  Tests for PointerExtensions.swift:
//  pointer subscripts, allocate, copy, init(wrapping:), retainIfObject
class PointerExtensionsTests: XCTestCase {

    func testPointerSemantics() {
        let point = Point(x: 5, y: 7)
        let yval = withUnsafeBytes(of: point) { ptr -> Int in
            return ptr.load(fromByteOffset: MemoryLayout<Int>.size, as: Int.self)
        }
        XCTAssertEqual(yval, 7)
    }

    func testUnsafeRawPointerSubscriptGetter() {
        var value: Int = 42
        withUnsafeBytes(of: &value) { bytes in
            let immutablePtr: UnsafeRawPointer = bytes.baseAddress!
            let result: Int = immutablePtr[0]
            XCTAssertEqual(result, 42)
        }
    }

    func testRawPointerSubscriptSetter() {
        var ptr = RawPointer.allocateBuffer(for: reflect(Int.self))
        defer { ptr.deallocate() }
        ptr[0] = 99 as Int
        let readBack: Int = ptr[0]
        XCTAssertEqual(readBack, 99)
    }

    func testRawPointerAllocateBuffer() {
        let ptr = RawPointer.allocateBuffer(for: reflect(Int.self))
        defer { ptr.deallocate() }
        XCTAssertNotNil(ptr)
    }

    func testRawPointerWrappingInit() {
        let meta = reflect(Int.self)
        let ptr = RawPointer(wrapping: 123 as Any, withType: meta)
        defer { ptr.deallocate() }
        let value: Int = ptr[0]
        XCTAssertEqual(value, 123)
    }

    func testRawPointerCopyMemoryTupleElement() {
        let tupleMeta = reflect((Int, Double).self) as! TupleMetadata
        let element = tupleMeta.elements[0]
        let dest = RawPointer.allocate(byteCount: tupleMeta.vwt.size,
                                       alignment: tupleMeta.vwt.flags.alignment)
        defer { dest.deallocate() }
        var srcValue: Int = 55
        withUnsafeBytes(of: &srcValue) { bytes in
            dest.copyMemory(ofTupleElement: bytes.baseAddress!, layout: element)
        }
        XCTAssertEqual(dest.load(fromByteOffset: element.offset, as: Int.self), 55)
    }

    func testRawPointerCopyMemoryFromType() {
        let meta = reflect(Int.self)
        let dest = RawPointer.allocateBuffer(for: meta)
        defer { dest.deallocate() }
        var srcValue: Int = 77
        withUnsafeMutableBytes(of: &srcValue) { bytes in
            dest.copyMemory(from: bytes.baseAddress!, type: meta)
        }
        XCTAssertEqual(dest[0] as Int, 77)
    }

    func testRetainIfObject() {
        let bob = Employee(name: "Bob", age: 55, position: "Programmer")
        XCTAssertTrue(Unmanaged<AnyObject>.retainIfObject(bob))
        XCTAssertFalse(Unmanaged<AnyObject>.retainIfObject(42))
    }
}
