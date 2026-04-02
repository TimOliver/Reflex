//
//  ReflexTests.swift
//  ReflexTests
//
//  Created by Tanner Bennett on 4/8/21.
//

import XCTest
import Combine
import Echo
@testable import Reflex

class ReflexTests: XCTestCase {
    var bob = Employee(name: "Bob", age: 55, position: "Programmer")
    lazy var employee = reflectClass(bob)!
    lazy var person = employee.superclassMetadata!
    lazy var employeeFields = employee.descriptor.fields
    lazy var personFields = person.descriptor.fields
    
    func assertFieldsEqual(_ expectedNames: [String], _ fields: FieldDescriptor) {
        let fieldNames: Set<String> = Set(fields.records.map(\.name))
        XCTAssertEqual(fieldNames, Set(expectedNames))
    }
    
    func testPointerSemantics() {
        let point = Point(x: 5, y: 7)
        let yval = withUnsafeBytes(of: point) { (ptr) -> Int in
            return ptr.load(fromByteOffset: MemoryLayout<Int>.size, as: Int.self)
        }
        
        XCTAssertEqual(yval, 7)
    }
    
    func testKVCGetters() {
        // Also exercise the superclass-fallback path in ClassMetadata:
        // asking Employee's metadata for a field that lives in Person
        XCTAssertEqual(bob.name, employee.getValue(forKey: "name", from: bob))
        assertFieldsEqual(["position", "salary", "cubicleSize"], employeeFields)
        assertFieldsEqual(["name", "age"], personFields)
        
        XCTAssertEqual(bob.position, employee.getValue(forKey: "position", from: bob))
        XCTAssertEqual(bob.salary, employee.getValue(forKey: "salary", from: bob))
        XCTAssertEqual(bob.cubicleSize, employee.getValue(forKey: "cubicleSize", from: bob))
        XCTAssertEqual(bob.name, person.getValue(forKey: "name", from: bob))
        XCTAssertEqual(bob.age, person.getValue(forKey: "age", from: bob))
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
    
    func testTypeNames() {
        XCTAssertEqual(person.descriptor.name, "Person")
    }
    
    func testAbilityToDetectSwiftTypes() {
        let nonSwiftObjects: [Any] = [
            NSObject.self,
            NSObject(),
            UIView.self,
            UIView(),
            "a string",
            12345,
            self.superclass!,
        ]
        
        let swiftObjects: [Any] = [
            ReflexTests.self,
            self,
            Person.self,
            bob,
            [1, 2, 3],
            [Point(x: 1, y: 2)]
        ]
        
        for obj in swiftObjects {
            XCTAssertTrue(isSwiftObjectOrClass(obj))
        }
        for obj in nonSwiftObjects {
            XCTAssertFalse(isSwiftObjectOrClass(obj))
        }
    }
    
    @available(iOS 13.0, *)
    func testTypeDescriptions() {
        typealias LongPublisher = Publishers.CombineLatest<AnyPublisher<Any, Error>,AnyPublisher<Any, Error>>
        
        XCTAssertEqual("Any",        reflect(Any.self).description)
        XCTAssertEqual("AnyObject",  reflect(AnyObject.self).description)
        XCTAssertEqual("AnyClass",   reflect(AnyClass.self).description)
        
        XCTAssertEqual("String?",              reflect(String?.self).description)
        XCTAssertEqual("Counter<Int>",         reflect(Counter<Int>.self).description)
        XCTAssertEqual("Array<Int>",           reflect([Int].self).description)
        XCTAssertEqual("(id: Int, 1: Person)", reflect((id: Int, Person).self).description)
        XCTAssertEqual("Counter<Int>",         reflect(Counter<Int>.self).description)
        XCTAssertEqual("Array<Counter<Int>>",  reflect([Counter<Int>].self).description)
        XCTAssertEqual("CombineLatest<AnyPublisher<Any, Error>, AnyPublisher<Any, Error>>",
                       reflect(LongPublisher.self).description
        )
        
        let ikur: (inout Person) -> Bool = isKnownUniquelyReferenced
        XCTAssertEqual("(ReflexTests) -> () -> ()", reflect(Self.testTypeDescriptions).description)
        XCTAssertEqual("(Person) -> Bool", reflect(ikur).description)
    }
    
    func testValueDescriptions() {
        // Primitives
        XCTAssertEqual(reflect(Int.self).typeEncodingString, "q")
        XCTAssertEqual(reflect(Bool.self).typeEncodingString, "B")
        XCTAssertEqual(reflect(Double.self).typeEncodingString, "d")

        // Foundation structs encode as their ObjC counterparts
        XCTAssertEqual(reflect(String.self).typeEncodingString, "@\"NSString\"")
        XCTAssertEqual(reflect(Date.self).typeEncodingString, "@\"NSDate\"")
        XCTAssertEqual(reflect(Data.self).typeEncodingString, "@\"NSData\"")
        XCTAssertEqual(reflect(URL.self).typeEncodingString, "@\"NSURL\"")

        // Custom struct
        XCTAssertEqual(reflect(Point.self).typeEncodingString, "{Point=qq}")

        // Optional unwraps to wrapped type's encoding
        XCTAssertEqual(reflect(Int?.self).typeEncodingString, "q")
        XCTAssertEqual(reflect(String?.self).typeEncodingString, "@\"NSString\"")
    }

    func testBoolTypeEncoding() {
        let holder = BoolHolder()
        let mirror = SwiftMirror(reflecting: holder)
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

    func testValueTypeMirrorDoesNotCrash() {
        // Passing a struct to SwiftMirror should return an empty mirror, not crash
        let point = Point(x: 3, y: 7)
        let mirror = SwiftMirror(reflecting: point)

        XCTAssertFalse(mirror.isClass)
        XCTAssertEqual(mirror.className, "Point")
        XCTAssertTrue(mirror.ivars.isEmpty)
        XCTAssertTrue(mirror.properties.isEmpty)
        XCTAssertTrue(mirror.protocols.isEmpty)
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
    
    func testTypeEncodings() {
        let rect = reflect(CGRect.self)
        XCTAssertEqual(rect.typeEncodingString, "{CGRect={CGPoint=dd}{CGSize=dd}}")
        
        let size = reflect(Size.self)
        XCTAssertEqual(size.typeEncodingString, "{Size=qq}")
    }
    
    func testStructFieldLabels() {
        let mirror = SwiftMirror(reflecting: Sprite.self)
        let structIvar = mirror.ivars.first(where: { $0.name == "boundingBox" })!
        
        let info = structIvar.auxiliaryInfo(forKey: FLEXAuxiliarynfoKeyFieldLabels)
        if let labels = info as? [String: [String]] {
            XCTAssertEqual(labels.count, 3)
            XCTAssertEqual(labels["{Rect={Point=qq}{Size=qq}}"], ["Point origin", "Size size"])
            XCTAssertEqual(labels["{Point=qq}"], ["Int x", "Int y"])
            XCTAssertEqual(labels["{Size=qq}"], ["Int width", "Int height"])
        } else {
            XCTFail()
        }
    }

    func testEnumTypeEncoding() {
        // Direction has 4 no-payload cases → stored as UInt8 (1 byte)
        let dirMeta = reflect(Direction.self)
        XCTAssertEqual(dirMeta.typeEncoding, .unsignedChar)
    }

    func testFoundationStructTypeEncodingString() {
        // String bridges to NSString — encoding should use the ObjC class name
        let stringMeta = reflect(String.self)
        XCTAssertEqual(stringMeta.typeEncodingString, "@\"NSString\"")

        let arrayMeta = reflect([Int].self)
        XCTAssertEqual(arrayMeta.typeEncodingString, "@\"NSArray\"")
    }

    func testStructFieldLabelsDeepRecursion() {
        // Path → Segment → Point is three levels deep.
        // The old code only walked one level (Path → Segment), missing Point.
        let mirror = SwiftMirror(reflecting: PathHolder())
        let pathIvar = mirror.ivars.first(where: { $0.name == "path" })!

        let info = pathIvar.auxiliaryInfo(forKey: FLEXAuxiliarynfoKeyFieldLabels)
        guard let labels = info as? [String: [String]] else {
            XCTFail("Expected [String: [String]]")
            return
        }

        // Three distinct struct types: Path, Segment, Point
        XCTAssertEqual(labels.count, 3)
        // Point must be present — it's 2 levels deep from Path
        XCTAssertEqual(labels["{Point=qq}"], ["Int x", "Int y"])
    }

    func testSwiftProtocolName() {
        let slider = RFSlider(color: .red, frame: .zero)
        let mirror = SwiftMirror(reflecting: slider)
        let p = mirror.protocols.compactMap { $0 as? SwiftProtocol }
            .first(where: { $0.name == "Slidable" })
        XCTAssertNotNil(p)
    }

    func testSwiftProtocolInheritedProtocols() {
        let thing = NamedThing()
        let mirror = SwiftMirror(reflecting: thing)
        let fullyNamed = mirror.protocols.compactMap { $0 as? SwiftProtocol }
            .first(where: { $0.name == "FullyNamed" })
        XCTAssertNotNil(fullyNamed)
        XCTAssertEqual(fullyNamed?.protocols.count, 1)
        XCTAssertEqual(fullyNamed?.protocols.first?.name, "Named")
    }

    func testSuperMirror() {
        let mirror = SwiftMirror(reflecting: bob)
        let sup = mirror.superMirror
        XCTAssertNotNil(sup)
        XCTAssertEqual((sup as? SwiftMirror)?.className, NSStringFromClass(Person.self))
    }

    func testReflexError() {
        let err = ReflexError.failedDynamicCast(src: Int.self, dest: String.self)
        XCTAssertTrue(err.description.contains("Int"))
        XCTAssertTrue(err.description.contains("String"))
    }

    func testTupleTypeEncoding() {
        let meta = reflect((Int, String).self)
        XCTAssertEqual(meta.typeEncoding, .structBegin)
        let str = meta.typeEncodingString
        XCTAssertTrue(str.hasPrefix("{"))
        XCTAssertTrue(str.contains("q"))           // Int → "q"
        XCTAssertTrue(str.contains("NSString"))    // String → @"NSString"
    }

    func testStructMetadataKVC() {
        // StructMetadata KVC operates on memory within a class instance.
        // Exercise it via Employee.cubicleSize, a struct-typed stored property on a class.
        let emp = Employee(name: "Alice", age: 30, position: "Engineer")
        let empMeta = reflectClass(Employee.self)!

        // getValue for a struct-typed field
        let size: Size = empMeta.getValue(forKey: "cubicleSize", from: emp)
        XCTAssertEqual(size, emp.cubicleSize)

        // getValueBox → toAny round-trip
        let box = empMeta.getValueBox(forKey: "cubicleSize", from: emp)
        XCTAssertEqual(box.toAny as? Size, emp.cubicleSize)
    }

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

        // No-payload case returns nil
        let nothingTag = meta.getTag(for: Tagged.nothing)
        XCTAssertEqual(nothingTag, UInt32(meta.descriptor.numPayloadCases))

        // Payload case round-trips
        let instance = Tagged.number(42)
        let tag = meta.getTag(for: instance)
        XCTAssertEqual(tag, 0) // .number is the first (index 0) payload case

        let payload = meta.copyPayload(from: instance)
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?.value as? Int, 42)

        XCTAssertNil(meta.copyPayload(from: Tagged.nothing))
    }

    func testSwiftIvarProperties() {
        // Use a field that belongs directly to Employee (not inherited from Person)
        let mirror = SwiftMirror(reflecting: bob)
        let positionIvar = mirror.ivars.first(where: { $0.name == "position" })!

        XCTAssertGreaterThan(positionIvar.offset, 0)
        XCTAssertGreaterThan(positionIvar.size, 0)
        XCTAssertNotNil(positionIvar.imagePath)
        XCTAssertFalse(positionIvar.details.isEmpty)
        XCTAssertEqual(positionIvar.getPotentiallyUnboxedValue(bob) as? String, "Programmer")
    }

    func testSwiftProtocolProperties() {
        let slider = RFSlider(color: .red, frame: .zero)
        let mirror = SwiftMirror(reflecting: slider)
        let p = mirror.protocols.compactMap { $0 as? SwiftProtocol }
            .first(where: { $0.name == "Slidable" })!

        // These properties should all be accessible without crashing
        _ = p.objc_protocol
        _ = p.imagePath
        _ = p.requiredMethods
        _ = p.optionalMethods
        _ = p.requiredProperties
        _ = p.optionalProperties
    }

    func testExistentialTypeDescription() {
        // Exercises ProtocolDescriptor.description via Metadata.description's .existential path
        let meta = reflect(Slidable.self)
        XCTAssertTrue(meta.description.contains("Slidable"))
    }

    func testFieldRecordDebugDescription() {
        let record = employee.descriptor.fields.records.first!
        XCTAssertFalse(record.debugDescription.isEmpty)
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

    func testIsNonTriviallyBridgedToObjc() {
        // Plain Foundation struct
        XCTAssertTrue(reflect(String.self).isNonTriviallyBridgedToObjc)
        // Optional of a Foundation struct walks through the .optional branch
        XCTAssertTrue(reflect(String?.self).isNonTriviallyBridgedToObjc)
        // Non-bridged types
        XCTAssertFalse(reflect(Int.self).isNonTriviallyBridgedToObjc)
        XCTAssertFalse(reflect(Point.self).isNonTriviallyBridgedToObjc)
        XCTAssertFalse(reflect(Employee.self).isNonTriviallyBridgedToObjc)
    }

    func testClassTypeEncodingString() {
        // Class types hit the fallback in typeEncodingString (not a Foundation struct, not optional)
        let meta = reflect(Employee.self)
        XCTAssertEqual(meta.typeEncoding, .objcObject)
        let str = meta.typeEncodingString
        XCTAssertTrue(str.hasPrefix("@\""))
        XCTAssertTrue(str.contains("Employee"))
    }

    func testEnumMetadataFields() {
        // EnumMetadata.fields delegates to shallowFields, which filters to payload cases
        let meta = reflect(Tagged.self) as! EnumMetadata
        let fields = meta.fields
        // Tagged has 2 payload cases: number(Int) and text(String); nothing has no payload
        XCTAssertEqual(fields.count, 2)
        let names = Set(fields.map(\.name))
        XCTAssertTrue(names.contains("number"))
        XCTAssertTrue(names.contains("text"))
    }

    func testContainerIsEmpty() {
        // A nil class-optional container has all-zero data → isEmpty == true
        let classMeta = reflectClass(Employee.self)!
        let nilContainer = AnyExistentialContainer(nil: classMeta)
        XCTAssertTrue(nilContainer.isEmpty)
    }

    func testOptionalStructTypeEncodingString() {
        // Optional<CustomStruct> has typeEncoding == .structBegin (delegates to wrapped type)
        // and kind == .optional — hits implicit closure #3 in typeEncodingString
        XCTAssertEqual(reflect(Point?.self).typeEncodingString, "{Point=qq}")
    }

    func testStructMetadataKVCViaPointer() {
        // StructMetadata KVC uses `object~` (unsafeBitCast to RawPointer).
        // Passing a RawPointer as O is safe: it's pointer-sized, so the bitcast is identity
        // and the resulting pointer IS the address of the struct's storage.
        var point = Point(x: 3, y: 7)
        let meta = reflectStruct(Point.self)!

        withUnsafeMutableBytes(of: &point) { bytes in
            var ptr: RawPointer = bytes.baseAddress!

            // getValue<T, O>
            let x: Int = meta.getValue(forKey: "x", from: ptr)
            XCTAssertEqual(x, 3)

            // getValueBox
            let yBox = meta.getValueBox(forKey: "y", from: ptr)
            XCTAssertEqual(yBox.toAny as? Int, 7)

            // set<T, O>(on: inout) — ptr~ == ptr (identity), writes to point.x
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
        // NSNumber ≠ Double in the type system, so ClassMetadata.set triggers
        // the try?-dynamicCast path (implicit closure #1); NSNumber→Double succeeds
        let emp = Employee(name: "Test", age: 30, position: "Dev", salary: 0)
        let meta = reflectClass(Employee.self)!
        meta.set(value: NSNumber(value: 75_000.0), forKey: "salary", pointer: emp~)
        XCTAssertEqual(emp.salary, 75_000.0)
    }

    func testDynamicCastFailure() {
        // Exercises the throw branch of Metadata.dynamicCast(from:)
        let meta = reflect(String.self)
        XCTAssertThrowsError(try meta.dynamicCast(from: 42 as Any))
    }

    func testAnyExistentialContainerNilEnum() {
        // Optional<Int> is an enum at the runtime level; init(nil: EnumMetadata)
        // creates an Optional<Int>.none wrapped in an existential
        let optMeta = reflect(Int?.self) as! EnumMetadata
        let nilBox = AnyExistentialContainer(nil: optMeta)
        // toAny gives Optional<Int>.none; casting it to Int? succeeds with a nil inner value
        let asOptional: Int?? = nilBox.toAny as? Int?
        XCTAssertNotNil(asOptional as Any?) // outer cast succeeded
        XCTAssertNil(asOptional!)           // inner Optional<Int> is .none
    }

    func testGetValueBufferAllocatesBox() {
        // FourInts is 32 bytes — larger than the 24-byte existential inline buffer,
        // so getValueBuffer() must allocate a heap box (implicit closure #1)
        var big = FourInts()
        let meta = reflectStruct(FourInts.self)!
        withUnsafeMutableBytes(of: &big) { bytes in
            let ptr: RawPointer = bytes.baseAddress!
            let box = AnyExistentialContainer(boxing: ptr, type: meta)
            XCTAssertFalse(box.isEmpty)
        }
    }

    func testRetainIfObject() {
        XCTAssertTrue(Unmanaged<AnyObject>.retainIfObject(bob))
        XCTAssertFalse(Unmanaged<AnyObject>.retainIfObject(42))
    }

    func testUnsafeRawPointerSubscriptGetter() {
        // UnsafeRawPointer (immutable) subscript getter
        var value: Int = 42
        withUnsafeBytes(of: &value) { bytes in
            let immutablePtr: UnsafeRawPointer = bytes.baseAddress!
            let result: Int = immutablePtr[0]
            XCTAssertEqual(result, 42)
        }
    }

    func testRawPointerSubscriptSetter() {
        // UnsafeMutableRawPointer subscript setter
        let meta = reflect(Int.self)
        var ptr = RawPointer.allocateBuffer(for: meta)
        defer { ptr.deallocate() }
        ptr[0] = 99 as Int
        let readBack: Int = ptr[0]
        XCTAssertEqual(readBack, 99)
    }

    func testRawPointerWrappingInit() {
        // RawPointer.init(wrapping:withType:) — allocates and stores a value
        let meta = reflect(Int.self)
        let ptr = RawPointer(wrapping: 123 as Any, withType: meta)
        defer { ptr.deallocate() }
        let value: Int = ptr[0]
        XCTAssertEqual(value, 123)
    }

    func testRawPointerCopyMemoryTupleElement() {
        // copyMemory(ofTupleElement:layout:)
        let tupleMeta = reflect((Int, Double).self) as! TupleMetadata
        let element = tupleMeta.elements[0]  // Int, offset 0
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
        // copyMemory(from:type:offset:)
        let meta = reflect(Int.self)
        let dest = RawPointer.allocateBuffer(for: meta)
        defer { dest.deallocate() }
        var srcValue: Int = 77
        withUnsafeMutableBytes(of: &srcValue) { bytes in
            dest.copyMemory(from: bytes.baseAddress!, type: meta)
        }
        let result: Int = dest[0]
        XCTAssertEqual(result, 77)
    }

    func testRawPointerAllocateBuffer() {
        let meta = reflect(Int.self)
        let ptr = RawPointer.allocateBuffer(for: meta)
        defer { ptr.deallocate() }
        XCTAssertEqual(ptr.load(as: UInt8.self), 0) // freshly allocated bytes
    }

    func testSwiftMirrorAvailable() {
        XCTAssertNotNil(NSClassFromString("FLEXSwiftMirror"))
    }
    
    func testSwiftMirror() {
        let slider = RFSlider(color: .red, frame: .zero)
        let sliderMirror = SwiftMirror(reflecting: slider)
        let bob = Employee(name: "Bob", age: 45, position: "Programmer", salary: 100_000)
        let employeeMirror = SwiftMirror(reflecting: bob)
        
        XCTAssertEqual(sliderMirror.ivars.count, 8)
        XCTAssertEqual(sliderMirror.properties.count, 1)
        XCTAssertEqual(sliderMirror.methods.count, 6)
        XCTAssertEqual(sliderMirror.protocols.count, 1)
        
        slider.tag = 0xAABB
        
        // Swift mirror //
        
        let smirror = Mirror(reflecting: slider)
        let smtag = smirror.children.filter { $0.label == "tag" }.first!.value as! Int
        XCTAssertEqual(smtag, slider.tag)
        
        // Echo //
        let tagp = sliderMirror.ivars.filter { $0.name == "tag" }.first!
        let titlep = sliderMirror.ivars.filter { $0.name == "title" }.first!
        let subtitlep = sliderMirror.ivars.filter { $0.name == "subtitle" }.first!
        let sizep = employeeMirror.ivars.filter { $0.name == "cubicleSize" }.first!
        
        // Read
        let tag: Int = tagp.getValue(slider) as! Int
        XCTAssertEqual(tag, slider.tag)
        // Write
        tagp.setValue(0xDDCC, on: slider)
        XCTAssertEqual(0xDDCC, slider.tag)
        let newTag = tagp.getValue(slider) as! Int
        XCTAssertEqual(newTag, slider.tag)
        
        // Type encodings
        XCTAssertEqual(tagp.type, .longLong)
        XCTAssertEqual(tagp.typeEncoding, "q")
        XCTAssertEqual(tagp.description, "NSInteger tag")
        XCTAssertEqual(titlep.description, "NSString title")
        XCTAssertEqual(subtitlep.description, "NSString subtitle")
        XCTAssertEqual(sizep.description, "Size cubicleSize")
    }
}
