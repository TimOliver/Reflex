//
//  PointerExtensionsTests.swift
//  ReflexTests
//
//  Tests for PointerExtensions.swift:
//  pointer subscripts, allocate, copy, init(wrapping:), retainIfObject
//

import XCTest
import Echo
@testable import Reflex

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
        let ptr = RawPointer.allocateBuffer(for: reflect(Int.self))
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
