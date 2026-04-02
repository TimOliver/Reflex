//
//  EchoExtensionsTests.swift
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
import Combine
import Echo
@testable import Reflex

//  Tests for EchoExtensions.swift:
//  type encodings, KVC, metadata operations, AnyExistentialContainer, dynamic cast
class EchoExtensionsTests: ReflexTests {

    // MARK: - Type descriptions

    func testTypeNames() {
        XCTAssertEqual(person.descriptor.name, "Person")
    }

    @available(iOS 13.0, *)
    func testTypeDescriptions() {
        typealias LongPublisher = Publishers.CombineLatest<AnyPublisher<Any, Error>, AnyPublisher<Any, Error>>

        XCTAssertEqual("Any",       reflect(Any.self).description)
        XCTAssertEqual("AnyObject", reflect(AnyObject.self).description)
        XCTAssertEqual("AnyClass",  reflect(AnyClass.self).description)

        XCTAssertEqual("String?",              reflect(String?.self).description)
        XCTAssertEqual("Counter<Int>",         reflect(Counter<Int>.self).description)
        XCTAssertEqual("Array<Int>",           reflect([Int].self).description)
        XCTAssertEqual("(id: Int, 1: Person)", reflect((id: Int, Person).self).description)
        XCTAssertEqual("Array<Counter<Int>>",  reflect([Counter<Int>].self).description)
        XCTAssertEqual(
            "CombineLatest<AnyPublisher<Any, Error>, AnyPublisher<Any, Error>>",
            reflect(LongPublisher.self).description
        )

        let ikur: (inout Person) -> Bool = isKnownUniquelyReferenced
        XCTAssertEqual("(EchoExtensionsTests) -> () -> ()", reflect(Self.testTypeDescriptions).description)
        XCTAssertEqual("(Person) -> Bool", reflect(ikur).description)
    }

    // MARK: - Type encodings

    func testValueDescriptions() {
        XCTAssertEqual(reflect(Int.self).typeEncodingString,    "q")
        XCTAssertEqual(reflect(Bool.self).typeEncodingString,   "B")
        XCTAssertEqual(reflect(Double.self).typeEncodingString, "d")

        XCTAssertEqual(reflect(String.self).typeEncodingString, "@\"NSString\"")
        XCTAssertEqual(reflect(Date.self).typeEncodingString,   "@\"NSDate\"")
        XCTAssertEqual(reflect(Data.self).typeEncodingString,   "@\"NSData\"")
        XCTAssertEqual(reflect(URL.self).typeEncodingString,    "@\"NSURL\"")

        XCTAssertEqual(reflect(Point.self).typeEncodingString,  "{Point=qq}")

        XCTAssertEqual(reflect(Int?.self).typeEncodingString,    "q")
        XCTAssertEqual(reflect(String?.self).typeEncodingString, "@\"NSString\"")
    }

    func testTypeEncodings() {
        XCTAssertEqual(reflect(CGRect.self).typeEncodingString, "{CGRect={CGPoint=dd}{CGSize=dd}}")
        XCTAssertEqual(reflect(Size.self).typeEncodingString,   "{Size=qq}")
    }

    func testEnumTypeEncoding() {
        // Direction has 4 no-payload cases → stored as UInt8 (1 byte)
        XCTAssertEqual(reflect(Direction.self).typeEncoding, .unsignedChar)
    }

    func testFoundationStructTypeEncodingString() {
        XCTAssertEqual(reflect(String.self).typeEncodingString, "@\"NSString\"")
        XCTAssertEqual(reflect([Int].self).typeEncodingString,  "@\"NSArray\"")
    }

    func testTupleTypeEncoding() {
        let meta = reflect((Int, String).self)
        XCTAssertEqual(meta.typeEncoding, .structBegin)
        let str = meta.typeEncodingString
        XCTAssertTrue(str.hasPrefix("{"))
        XCTAssertTrue(str.contains("q"))
        XCTAssertTrue(str.contains("NSString"))
    }

    func testOptionalStructTypeEncodingString() {
        // typeEncoding == .structBegin (delegates to wrapped type), kind == .optional
        XCTAssertEqual(reflect(Point?.self).typeEncodingString, "{Point=qq}")
    }

    func testClassTypeEncodingString() {
        // Class types hit the fallback path: not a Foundation struct, not optional
        let meta = reflect(Employee.self)
        XCTAssertEqual(meta.typeEncoding, .objcObject)
        XCTAssertTrue(meta.typeEncodingString.hasPrefix("@\""))
        XCTAssertTrue(meta.typeEncodingString.contains("Employee"))
    }

    func testIsNonTriviallyBridgedToObjc() {
        XCTAssertTrue(reflect(String.self).isNonTriviallyBridgedToObjc)
        XCTAssertTrue(reflect(String?.self).isNonTriviallyBridgedToObjc)  // .optional branch
        XCTAssertFalse(reflect(Int.self).isNonTriviallyBridgedToObjc)
        XCTAssertFalse(reflect(Point.self).isNonTriviallyBridgedToObjc)
        XCTAssertFalse(reflect(Employee.self).isNonTriviallyBridgedToObjc)
    }

    // MARK: - KVC

    func testKVCGetters() {
        // Also exercises the superclass-fallback path: asking Employee for a field in Person
        XCTAssertEqual(bob.name, employee.getValue(forKey: "name", from: bob))
        assertFieldsEqual(["position", "salary", "cubicleSize"], employeeFields)
        assertFieldsEqual(["name", "age"], personFields)

        XCTAssertEqual(bob.position,    employee.getValue(forKey: "position", from: bob))
        XCTAssertEqual(bob.salary,      employee.getValue(forKey: "salary", from: bob))
        XCTAssertEqual(bob.cubicleSize, employee.getValue(forKey: "cubicleSize", from: bob))
        XCTAssertEqual(bob.name, person.getValue(forKey: "name", from: bob))
        XCTAssertEqual(bob.age,  person.getValue(forKey: "age", from: bob))
    }

    func testKVCSetters() {
        person.set(value: "Robert", forKey: "name", on: &bob)
        XCTAssertEqual("Robert", bob.name)
        XCTAssertEqual(bob.name, person.getValue(forKey: "name", from: bob))

        person.set(value: 23, forKey: "age", on: &bob)
        XCTAssertEqual(23, bob.age)
        XCTAssertEqual(bob.age, person.getValue(forKey: "age", from: bob))

        employee.set(value: "Janitor", forKey: "position", on: &bob)
        XCTAssertEqual("Janitor", bob.position)
        XCTAssertEqual(bob.position, employee.getValue(forKey: "position", from: bob))

        employee.set(value: 3.14159, forKey: "salary", on: &bob)
        XCTAssertEqual(3.14159, bob.salary)
        XCTAssertEqual(bob.salary, employee.getValue(forKey: "salary", from: bob))
    }

    func testStructMetadataKVC() {
        // StructMetadata KVC via a class instance: Employee.cubicleSize is struct-typed
        let emp = Employee(name: "Alice", age: 30, position: "Engineer")
        let empMeta = reflectClass(Employee.self)!

        let size: Size = empMeta.getValue(forKey: "cubicleSize", from: emp)
        XCTAssertEqual(size, emp.cubicleSize)

        let box = empMeta.getValueBox(forKey: "cubicleSize", from: emp)
        XCTAssertEqual(box.toAny as? Size, emp.cubicleSize)
    }

    func testStructMetadataKVCViaPointer() {
        // StructMetadata KVC uses `object~` (unsafeBitCast to RawPointer).
        // Passing a RawPointer as O is safe: pointer-sized, bitcast is identity,
        // and the result IS the address of the struct's storage.
        var point = Point(x: 3, y: 7)
        let meta = reflectStruct(Point.self)!

        withUnsafeMutableBytes(of: &point) { bytes in
            var ptr: RawPointer = bytes.baseAddress!

            let x: Int = meta.getValue(forKey: "x", from: ptr)
            XCTAssertEqual(x, 3)

            let yBox = meta.getValueBox(forKey: "y", from: ptr)
            XCTAssertEqual(yBox.toAny as? Int, 7)

            meta.set(value: 10, forKey: "x", on: &ptr)
        }
        XCTAssertEqual(point.x, 10)
    }

    func testGetValueBoxSuperclassField() {
        // Exercises the superclass-recursion path in ClassMetadata.getValueBox
        let box = employee.getValueBox(forKey: "name", from: bob)
        XCTAssertEqual(box.toAny as? String, bob.name)
    }

    func testKVCSetWithBridgedValue() {
        // NSNumber ≠ Double → ClassMetadata.set triggers the try?-dynamicCast path
        let emp = Employee(name: "Test", age: 30, position: "Dev", salary: 0)
        reflectClass(Employee.self)!.set(value: NSNumber(value: 75_000.0), forKey: "salary", pointer: emp~)
        XCTAssertEqual(emp.salary, 75_000.0)
    }

    // MARK: - Metadata

    func testMetadataKindIsObject() {
        XCTAssertTrue(reflect(Employee.self).kind.isObject)
        XCTAssertFalse(reflect(Point.self).kind.isObject)
        XCTAssertFalse(reflect(Direction.self).kind.isObject)
    }

    func testConformsTo() {
        let sliderMeta = reflectClass(RFSlider.self)!
        XCTAssertTrue(sliderMeta.conforms(to: Slidable.self))
        XCTAssertFalse(sliderMeta.conforms(to: FullyNamed.self))
    }

    func testEnumPayload() {
        let meta = reflect(Tagged.self) as! EnumMetadata

        XCTAssertEqual(meta.getTag(for: Tagged.nothing), UInt32(meta.descriptor.numPayloadCases))

        let instance = Tagged.number(42)
        XCTAssertEqual(meta.getTag(for: instance), 0)

        let payload = meta.copyPayload(from: instance)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.value as? Int, 42)

        XCTAssertNil(meta.copyPayload(from: Tagged.nothing))
    }

    func testEnumMetadataFields() {
        let meta = reflect(Tagged.self) as! EnumMetadata
        let fields = meta.fields
        XCTAssertEqual(fields.count, 2)
        let names = Set(fields.map(\.name))
        XCTAssertTrue(names.contains("number"))
        XCTAssertTrue(names.contains("text"))
    }

    func testFieldRecordDebugDescription() {
        XCTAssertFalse(employee.descriptor.fields.records.first!.debugDescription.isEmpty)
    }

    func testExistentialTypeDescription() {
        XCTAssertTrue(reflect(Slidable.self).description.contains("Slidable"))
    }

    // MARK: - AnyExistentialContainer

    func testContainerIsEmpty() {
        let nilContainer = AnyExistentialContainer(nil: reflectClass(Employee.self)!)
        XCTAssertTrue(nilContainer.isEmpty)
    }

    func testAnyExistentialContainerNilEnum() {
        // Optional<Int> is an enum at the runtime level
        let optMeta = reflect(Int?.self) as! EnumMetadata
        let nilBox = AnyExistentialContainer(nil: optMeta)
        let asOptional: Int?? = nilBox.toAny as? Int?
        XCTAssertNotNil(asOptional as Any?)
        XCTAssertNil(asOptional!)
    }

    func testGetValueBufferAllocatesBox() {
        // FourInts is 32 bytes > 24-byte inline buffer → getValueBuffer allocates a heap box
        var big = FourInts()
        let meta = reflectStruct(FourInts.self)!
        withUnsafeMutableBytes(of: &big) { bytes in
            let ptr: RawPointer = bytes.baseAddress!
            let box = AnyExistentialContainer(boxing: ptr, type: meta)
            XCTAssertFalse(box.isEmpty)
        }
    }

    // MARK: - Field offset / ivar offset nil paths

    func testFieldOffsetNilForMissingKey() {
        // Covers the `return nil` branch in ContextualNominalType.fieldOffset(for:)
        let meta = reflectStruct(Point.self)!
        XCTAssertNil(meta.fieldOffset(for: "nonExistent"))
    }

    func testIvarOffsetNilForMissingObjCKey() {
        // Covers return nil in objcIvar (guard on firstIndex) and ivarOffset (guard on objcIvar)
        let meta = reflectClass(RFSlider.self)!
        XCTAssertNil(meta.ivarOffset(for: "nonExistentProperty"))
    }

    func testKVCSetSuperclassRecursion() {
        // employee.set for "name" (a Person field) exercises ClassMetadata.set superclass-recursion
        let emp = Employee(name: "Old", age: 30, position: "Dev")
        employee.set(value: "New" as Any, forKey: "name", pointer: emp~)
        XCTAssertEqual(emp.name, "New")
    }

    func testKVCSetDynamicCastSuccess() {
        // NSNumber ≠ Int → enters type-mismatch branch; NSNumber→Int bridging succeeds
        let emp = Employee(name: "Test", age: 0, position: "Dev")
        person.set(value: NSNumber(value: 30), forKey: "age", pointer: emp~)
        XCTAssertEqual(emp.age, 30)
    }

    // MARK: - Dynamic cast / ReflexError

    func testDynamicCastFailure() {
        XCTAssertThrowsError(try reflect(String.self).dynamicCast(from: 42 as Any))
    }

    func testReflexError() {
        let err = ReflexError.failedDynamicCast(src: Int.self, dest: String.self)
        XCTAssertTrue(err.description.contains("Int"))
        XCTAssertTrue(err.description.contains("String"))
    }
}
