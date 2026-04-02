//
//  EchoExtensions.swift
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

import Foundation
import Echo
import CEcho
import FLEX

/// An untyped pointer to a Swift type's metadata record in the runtime's read-only segment.
typealias RawType = UnsafeRawPointer

/// A name–metadata pair representing a single stored field in a nominal type.
typealias Field = (name: String, type: Metadata)

/// Errors that can be thrown by Reflex reflection operations.
enum ReflexError: Error {
    /// The runtime was unable to cast a value from one type to another.
    ///
    /// - Parameters:
    ///   - src: The actual type of the value that was being cast.
    ///   - dest: The target type of the failed cast.
    case failedDynamicCast(src: Any.Type, dest: Any.Type)

    /// A human-readable description of the error, including both type names.
    var description: String {
        switch self {
            case .failedDynamicCast(let src, let dest):
                return "Dynamic cast from type '\(src)' to '\(dest)' failed"
        }
    }
}

/// For some reason, breaking it all out into separate vars like this
/// eliminated a bug where the pointers in the final set were not the
/// same pointers that would appear if you manually reflected a type
extension KnownMetadata.Builtin {
    /// The set of raw metadata pointers for all supported primitive Swift scalar types.
    ///
    /// Used to quickly determine whether an arbitrary `Metadata` value represents a built-in
    /// type without walking the type descriptor hierarchy.
    static var supported: Set<RawType> = Set(_typePtrs)

    private static var _types: [Any.Type] = [
        Int8.self, Int16.self, Int32.self, Int64.self, Int.self,
        UInt8.self, UInt16.self, UInt32.self, UInt64.self, UInt.self,
        Float.self, Double.self, CGFloat.self,
        Bool.self,
    ]

    private static var _typePtrs: [RawType] {
        return self._types.map { ~$0 }
    }

    /// A mapping from raw metadata pointer to the corresponding `FLEXTypeEncoding` value
    /// for every supported primitive Swift scalar type.
    static var typeEncodings: [RawType: FLEXTypeEncoding] = [
        ~Int8.self: .char,
        ~Int16.self: .short,
        ~Int32.self: .int,
        ~Int64.self: .longLong,
        ~Int.self: .longLong,
        ~UInt8.self: .unsignedChar,
        ~UInt16.self: .unsignedShort,
        ~UInt32.self: .unsignedInt,
        ~UInt64.self: .unsignedLongLong,
        ~UInt.self: .unsignedLongLong,
        ~Float32.self: .float,
        ~Float64.self: .double,
        ~CGFloat.self: .double,
        ~Bool.self: .cBool,
    ]
}

extension KnownMetadata {
    static let string: StructDescriptor = reflectStruct(String.self)!.descriptor
    static let array: StructDescriptor = reflectStruct([Any].self)!.descriptor
    static let dictionary: StructDescriptor = reflectStruct([String:Any].self)!.descriptor
    static let date: StructDescriptor = reflectStruct(Date.self)!.descriptor
    static let data: StructDescriptor = reflectStruct(Data.self)!.descriptor
    static let url: StructDescriptor = reflectStruct(URL.self)!.descriptor

    /// The set of raw struct-descriptor pointers for Foundation value types that bridge
    /// non-trivially to Objective-C (i.e. as `NSString`, `NSArray`, `NSDictionary`,
    /// `NSDate`, `NSData`, and `NSURL`).
    static let foundationStructs: Set<RawType> = Set([
        string, array, dictionary, date, data, url
    ].map(\.ptr))

    /// Returns `true` when `metadata` describes one of the known Foundation struct types
    /// that bridge non-trivially to an Objective-C class.
    ///
    /// - Parameter metadata: The type metadata to test.
    /// - Returns: `true` if `metadata` is a `StructMetadata` whose descriptor is in
    ///   `foundationStructs`; `false` otherwise.
    static func isFoundationStruct(_ metadata: Metadata) -> Bool {
        guard let metadata = metadata as? StructMetadata else {
            return false
        }

        return foundationStructs.contains(metadata.descriptor.ptr)
    }

    /// A mapping from Foundation struct-descriptor pointer to the corresponding ObjC class.
    ///
    /// Used to produce correct `@"ClassName"` type encoding strings for types like
    /// `String` (→ `NSString`) and `[Any]` (→ `NSArray`).
    static let foundationTypeDescriptorToClass: [RawType: AnyClass] = [
        string.ptr: NSString.self,
        array.ptr: NSArray.self,
        dictionary.ptr: NSDictionary.self,
        date.ptr: NSDate.self,
        data.ptr: NSData.self,
        url.ptr: NSURL.self,
    ]

    /// Returns the Objective-C bridged class for a Foundation struct type, if one exists.
    ///
    /// - Parameter metadata: The type metadata to look up.
    /// - Returns: The corresponding `AnyClass` (e.g. `NSString.self` for `String`),
    ///   or `nil` if `metadata` is not a known Foundation struct.
    static func classForStruct(_ metadata: Metadata) -> AnyClass? {
        guard let metadata = metadata as? StructMetadata else {
            return nil
        }

        return foundationTypeDescriptorToClass[metadata.descriptor.ptr]
    }
}

extension Metadata {
    private var `enum`: EnumMetadata { self as! EnumMetadata }
    private var `struct`: StructMetadata { self as! StructMetadata }
    private var tuple: TupleMetadata { self as! TupleMetadata }

    /// Whether this type is a primitive scalar type (e.g. `Int`, `Bool`, `Double`).
    ///
    /// A type is considered built-in when it is plain-old-data (no reference counting)
    /// and its metadata pointer appears in `KnownMetadata.Builtin.supported`.
    var isBuiltin: Bool {
        guard self.vwt.flags.isPOD else {
            return false
        }

        return KnownMetadata.Builtin.supported.contains(self.ptr)
    }

    /// Whether this type is a non-primitive struct that bridges to an Objective-C object.
    ///
    /// `true` for Foundation value types such as `String`, `[T]`, `Date`, `Data`, and `URL`,
    /// as well as `Optional` wrappers around those types. `false` for primitive scalars,
    /// plain structs, and class types.
    var isNonTriviallyBridgedToObjc: Bool {
        switch self.kind {
            case .struct:
                return KnownMetadata.isFoundationStruct(self.struct)
            case .optional:
                return self.enum.optionalType.isNonTriviallyBridgedToObjc

            default:
                return false
        }
    }

    /// Performs a runtime dynamic cast equivalent to `variable as? T`, where `T` is
    /// the type described by this metadata.
    ///
    /// - Parameter variable: The `Any`-boxed value to cast.
    /// - Returns: The value cast to the type described by this metadata.
    /// - Throws: ``ReflexError/failedDynamicCast(src:dest:)`` if the cast fails.
    func dynamicCast(from variable: Any) throws -> Any {
        func cast<T>(_: T.Type) throws -> T {
            guard let casted = variable as? T else {
                let srcType = Swift.type(of: variable)
                throw ReflexError.failedDynamicCast(src: srcType, dest: T.self)
            }

            return casted
        }

        return try _openExistential(self.type, do: cast(_:))
    }

    /// The coarse-grained Objective-C type encoding character for this type.
    ///
    /// - Scalars: mapped via `KnownMetadata.Builtin.typeEncodings`.
    /// - Foundation structs and classes: `.objcObject`.
    /// - Custom structs and tuples: `.structBegin`.
    /// - No-payload enums: sized unsigned integer encoding.
    /// - All other kinds: `.unknown`.
    var typeEncoding: FLEXTypeEncoding {
        switch self.kind {
            case .class:
                return .objcObject

            case .struct:
                // Hard-code types for builtin types and a few foundation structs
                if self.isBuiltin {
                    return KnownMetadata.Builtin.typeEncodings[~self.type]!
                }
                // If it bridges to Objc and _isn't_ a primitive, treat it as an object
                if self.isNonTriviallyBridgedToObjc {
                    // TODO encode as proper type
                    return .objcObject
                }

                return .structBegin

            case .enum:
                if self.enum.descriptor.numPayloadCases > 0 {
                    return .unknown
                }
                switch self.vwt.size {
                case 1: return .unsignedChar
                case 2: return .unsignedShort
                case 4: return .unsignedInt
                case 8: return .unsignedLongLong
                default: return .unknown
                }

            case .optional:
                // For optionals, use the encoding of the Wrapped type
                return self.enum.optionalType!.typeEncoding

            case .tuple:
                return .structBegin

            case .foreignClass,
                 .opaque,
                 .function,
                 .existential,
                 .metatype,
                 .objcClassWrapper,
                 .existentialMetatype,
                 .heapLocalVariable,
                 .heapGenericLocalVariable,
                 .errorObject:
                return .unknown
        }
    }

    // TODO: enums would show up as anonymous structs I think
    /// The full Objective-C type encoding string for this type.
    ///
    /// - For object types, produces `@"ClassName"`, resolving Foundation structs to their
    ///   bridged ObjC class names (e.g. `String` → `@"NSString"`).
    /// - For struct and tuple types, recursively encodes all field types into
    ///   `{TypeName=field1field2...}` notation.
    /// - For optional struct types, delegates to the wrapped type's encoding string.
    /// - For scalar types, returns the single-character encoding (e.g. `"q"` for `Int`).
    var typeEncodingString: String {
        switch self.typeEncoding {
            case .objcObject:
                // Optional<FoundationStruct> inherits the encoding of its wrapped type
                if self.kind == .optional {
                    return self.enum.optionalType!.typeEncodingString
                }
                if let cls = KnownMetadata.classForStruct(self) {
                    return FLEXTypeEncoding.encodeObjcObject(typeName: NSStringFromClass(cls))
                }
                return FLEXTypeEncoding.encodeObjcObject(typeName: self.description)
            case .structBegin:
                switch self.kind {
                    case .tuple:
                        let fieldTypes = self.tuple.elements.map(\.metadata.typeEncodingString)
                        return FLEXTypeEncoding.encodeStruct(typeName: self.description, fields: fieldTypes)
                    case .struct:
                        let fieldTypes = self.struct.fields.map(\.type.typeEncodingString)
                        return FLEXTypeEncoding.encodeStruct(typeName: self.description, fields: fieldTypes)
                    case .optional:
                        return self.enum.optionalType!.typeEncodingString
                    default:
                        fatalError("typeEncodingString: unexpected kind \(self.kind) for .structBegin encoding")
                }
            default:
                // For now, convert type encoding char into a string
                return String(Character(.init(UInt8(bitPattern: self.typeEncoding.rawValue))))
        }
    }
}

/// A nominal type (class, struct, or enum) with generic parameters and stored fields.
protocol NominalType: TypeMetadata {
    /// The metadata for each generic type argument this type was instantiated with.
    var genericMetadata: [Metadata] { get }
    /// The byte offsets of each stored field within an instance, in declaration order.
    var fieldOffsets: [Int] { get }
    /// All stored fields of this type as name–metadata pairs.
    var fields: [Field] { get }
    /// A human-readable description of this type, including any generic arguments.
    var description: String { get }
}

/// A ``NominalType`` that also exposes its typed type-context descriptor.
///
/// Conforming types (``ClassMetadata``, ``StructMetadata``, ``EnumMetadata``) gain
/// shared KVC and field-lookup implementations via protocol extensions.
protocol ContextualNominalType: NominalType {
    associatedtype NominalTypeDescriptor: TypeContextDescriptor
    /// The type-context descriptor for this type, providing field records and generic info.
    var descriptor: NominalTypeDescriptor { get }
}

extension ClassMetadata: NominalType, ContextualNominalType {
    typealias NominalTypeDescriptor = ClassDescriptor
}
extension StructMetadata: NominalType, ContextualNominalType {
    typealias NominalTypeDescriptor = StructDescriptor
}
extension EnumMetadata: NominalType, ContextualNominalType {
    typealias NominalTypeDescriptor = EnumDescriptor
}

// MARK: KVC
extension ContextualNominalType {
    /// Returns the index of the field record with the given name within this type's descriptor.
    ///
    /// Only searches the fields declared directly on this type; does not traverse superclasses.
    ///
    /// - Parameter key: The field name to search for.
    /// - Returns: The zero-based index of the matching field record, or `nil` if not found.
    func recordIndex(forKey key: String) -> Int? {
        return self.descriptor.fields.records.firstIndex { $0.name == key }
    }

    /// Returns the byte offset of the field with the given name within an instance of this type.
    ///
    /// Only searches fields declared directly on this type; does not traverse superclasses.
    ///
    /// - Parameter key: The field name to look up.
    /// - Returns: The byte offset of the field, or `nil` if no field with that name exists.
    func fieldOffset(for key: String) -> Int? {
        if let idx = self.recordIndex(forKey: key) {
            return self.fieldOffsets[idx]
        }

        return nil
    }

    /// Returns the type metadata for the field with the given name.
    ///
    /// - Parameter key: The field name to look up.
    /// - Returns: The `Metadata` for the field's type, or `nil` if no such field exists.
    func fieldType(for key: String) -> Metadata? {
        return self.fields.first(where: { $0.name == key })?.type
    }

    /// The stored fields declared directly on this type, excluding any inherited fields.
    ///
    /// Each element pairs the field's name with its fully-resolved `Metadata`. Fields
    /// whose mangled type name cannot be resolved are omitted.
    var shallowFields: [Field] {
        let r: [FieldRecord] = self.descriptor.fields.records
        return r.filter(\.hasMangledTypeName).map {
            return (
                $0.name,
                reflect(self.type(of: $0.mangledTypeName)!)
            )
        }
    }
}

extension StructMetadata {
    /// Reads a field value of type `T` from a struct instance (or pointer) `object`.
    ///
    /// The field's byte offset is resolved from the struct's metadata and applied to
    /// the raw pointer representation of `object` via `unsafeBitCast`.
    ///
    /// - Parameters:
    ///   - key: The name of the field to read.
    ///   - object: The struct instance, or a `RawPointer` to its storage.
    /// - Returns: The field value cast to `T`.
    func getValue<T, O>(forKey key: String, from object: O) -> T {
        let offset = self.fieldOffset(for: key)!
        let ptr = object~
        return ptr[offset]
    }

    /// Returns the value of the named field wrapped in an ``AnyExistentialContainer``.
    ///
    /// The container owns a copy of the field value and can be read back via `toAny`.
    ///
    /// - Parameters:
    ///   - key: The name of the field to read.
    ///   - object: The struct instance, or a `RawPointer` to its storage.
    /// - Returns: An ``AnyExistentialContainer`` holding a copy of the field's value.
    func getValueBox<O>(forKey key: String, from object: O) -> AnyExistentialContainer {
        guard let offset = self.fieldOffset(for: key), let type = self.fieldType(for: key) else {
            fatalError("Class '\(self.descriptor.name)' has no member '\(key)'")
        }

        let ptr = object~
        return .init(boxing: ptr + offset, type: type)
    }

    /// Writes a value of type `T` into the named field of a struct passed by `inout` reference.
    ///
    /// - Parameters:
    ///   - value: The new value to store.
    ///   - key: The name of the field to write.
    ///   - object: An `inout` reference to the target struct instance.
    func set<T, O>(value: T, forKey key: String, on object: inout O) {
        self.set(value: value, forKey: key, pointer: object~)
    }

    /// Writes an `Any`-boxed value into the named field at the given raw pointer.
    ///
    /// The value is copied using the field type's value-witness table, preserving
    /// reference-counting semantics for object-typed fields.
    ///
    /// - Parameters:
    ///   - value: The new value to store, boxed as `Any`.
    ///   - key: The name of the field to write.
    ///   - ptr: A `RawPointer` to the base of the struct's storage.
    func set(value: Any, forKey key: String, pointer ptr: RawPointer) {
        let offset = self.fieldOffset(for: key)!
        let type = self.fieldType(for: key)!
        ptr.storeBytes(of: value, type: type, offset: offset)
    }

    /// All stored fields declared directly on this struct type.
    var fields: [Field] { self.shallowFields }
}

extension ClassMetadata {
    /// Returns the ObjC `Ivar` for the named field declared directly on this class.
    ///
    /// Uses `class_copyIvarList` indexed by the field's position in the type descriptor,
    /// rather than `class_getInstanceVariable`, to correctly handle resilient base classes
    /// where Swift's field offsets may not match ObjC's.
    ///
    /// Does not traverse the class hierarchy — only fields declared on this exact class.
    ///
    /// - Parameter key: The field name to look up.
    /// - Returns: The matching `Ivar`, or `nil` if the field is not found on this class.
    private func objcIvar(for key: String) -> Ivar? {
        guard let idx = self.descriptor.fields.records.map(\.name)
                .firstIndex(where: { $0 == key }) else {
            return nil
        }

        var count: UInt32 = 0
        guard let ivars = class_copyIvarList(self.type as? AnyClass, &count) else {
            return nil
        }

        defer { free(ivars) }
        return ivars[idx]
    }

    /// Returns the byte offset of the named instance variable within an instance of this class.
    ///
    /// For classes with Objective-C heritage (`usesSwiftRefCounting == false`), the offset
    /// is read from ObjC runtime metadata via `ivar_getOffset` to correctly handle resilient
    /// base classes. For pure Swift classes, the offset is read from Swift's field-offset table.
    ///
    /// Does not traverse the class hierarchy.
    ///
    /// - Parameter key: The field name to look up.
    /// - Returns: The byte offset of the ivar, or `nil` if the field is not declared on this class.
    func ivarOffset(for key: String) -> Int? {
        // If the class has objc heritage, get the field offset using the objc
        // metadata, because Swift won't update the field offsets in the face of
        // resilient base classes
        guard self.flags.usesSwiftRefCounting else {
            guard let ivar = self.objcIvar(for: key) else {
                return nil
            }

            return ivar_getOffset(ivar)
        }

        // Does this ivar exist?
        guard let idx = self.recordIndex(forKey: key) else {
            // Not here, but maybe in a superclass
            return nil
        }

        // Yes! Now, grab the offset and offset it by the superclass's instance size
//        if let supercls = self.superclassMetadata?.type {
//            return self.fieldOffsets[idx] //+ class_getInstanceSize(supercls as? AnyClass)
//        }

        return self.fieldOffsets[idx]
    }

    /// Reads a field value of type `T` from a class instance, searching superclasses if needed.
    ///
    /// If the field is not declared on this class, the search recurses into the Swift
    /// superclass metadata chain. Traps if the field is not found anywhere in the hierarchy.
    ///
    /// - Parameters:
    ///   - key: The field name to read.
    ///   - object: The class instance (or `RawPointer` to its storage).
    /// - Returns: The field value cast to `T`.
    func getValue<T, O>(forKey key: String, from object: O) -> T {
        guard let offset = self.ivarOffset(for: key) else {
            if let sup = self.superclassMetadata {
                return sup.getValue(forKey: key, from: object)
            } else {
                fatalError("Class '\(self.descriptor.name)' has no member '\(key)'")
            }
        }

        let ptr = object~
        return ptr[offset]
    }

    /// Returns the value of the named field wrapped in an ``AnyExistentialContainer``,
    /// searching superclasses if the field is not declared on this class.
    ///
    /// Traps if the field is not found anywhere in the class hierarchy.
    ///
    /// - Parameters:
    ///   - key: The field name to read.
    ///   - object: The class instance (or `RawPointer` to its storage).
    /// - Returns: An ``AnyExistentialContainer`` holding a copy of the field's value.
    func getValueBox<O>(forKey key: String, from object: O) -> AnyExistentialContainer {
        guard let offset = self.ivarOffset(for: key), let type = self.fieldType(for: key) else {
            if let sup = self.superclassMetadata {
                return sup.getValueBox(forKey: key, from: object)
            } else {
                fatalError("Class '\(self.descriptor.name)' has no member '\(key)'")
            }
        }

        let ptr = object~
        return .init(boxing: ptr + offset, type: type)
    }

    /// Writes a value of type `T` into the named field of a class instance passed `inout`.
    ///
    /// - Parameters:
    ///   - value: The new value to store.
    ///   - key: The name of the field to write.
    ///   - object: An `inout` reference to the target instance.
    func set<T, O>(value: T, forKey key: String, on object: inout O) {
        self.set(value: value, forKey: key, pointer: object~)
    }

    /// Writes an `Any`-boxed value into the named field at the given raw pointer,
    /// recursing into the superclass chain if the field is not on this class.
    ///
    /// If the runtime type of `value` does not match the field's declared type, a dynamic
    /// cast is attempted (e.g. `NSNumber` → `Double`). Logs an assertion failure if the
    /// cast cannot be performed.
    ///
    /// - Parameters:
    ///   - value: The new value to store, boxed as `Any`.
    ///   - key: The name of the field to write.
    ///   - ptr: A `RawPointer` to the base of the object's storage.
    func set(value: Any, forKey key: String, pointer ptr: RawPointer) {
        guard let offset = self.ivarOffset(for: key) else {
            if let sup = self.superclassMetadata {
                return sup.set(value: value, forKey: key, pointer: ptr)
            } else {
                fatalError("Class '\(self.descriptor.name)' has no member '\(key)'")
            }
        }

        var value = value
        let box = container(for: value)

        // Check if we need to do a cast first; sometimes things like
        // Double or Int will be boxed up as NSNumber first.
        let type = self.fieldType(for: key)!
        if type.type != box.type {
            if let cast = try? type.dynamicCast(from: value) {
                value = cast
            } else {
                assertionFailure("set(value:forKey:pointer:): could not cast \(Swift.type(of: value)) to field type \(type.type) for key '\(key)'")
            }
        }

        ptr.storeBytes(of: value, type: type, offset: offset)
    }

    /// All stored fields in the full class hierarchy, starting with fields declared on this
    /// class followed by those from each Swift superclass in order.
    ///
    /// Stops at the first non-Swift superclass (e.g. `NSObject`).
    var fields: [Field] {
        if let sup = self.superclassMetadata, sup.isSwiftClass {
            return self.shallowFields + sup.fields
        }

        return self.shallowFields
    }
}

extension EnumMetadata {
    /// All stored fields (payload cases) declared on this enum type.
    var fields: [Field] { self.shallowFields }
}

// MARK: Protocol conformance checking
extension TypeMetadata {
    /// Returns whether this type conforms to the given Swift protocol.
    ///
    /// The protocol must be passed as a metatype value (e.g. `Equatable.self`).
    /// Conformance is checked by scanning the type's runtime conformance records.
    ///
    /// - Parameter _protocol: A protocol metatype value such as `MyProtocol.self`.
    /// - Returns: `true` if this type has a conformance record for the given protocol.
    func conforms(to _protocol: Any) -> Bool {
        let existential = reflect(_protocol) as! MetatypeMetadata
        let instance = existential.instanceMetadata as! ExistentialMetadata
        let desc = instance.protocols.first!

        return !self.conformances.filter({ $0.protocol == desc }).isEmpty
    }
}

// MARK: MetadataKind
extension MetadataKind {
    /// Whether this metadata kind represents a reference type (class or ObjC class wrapper).
    var isObject: Bool {
        return self == .class || self == .objcClassWrapper
    }
}

// MARK: Populating AnyExistentialContainer
extension AnyExistentialContainer {
    /// The value held by this container, reinterpreted as `Any` via `unsafeBitCast`.
    var toAny: Any {
        return unsafeBitCast(self, to: Any.self)
    }

    /// Whether this container's inline data buffer is entirely zero (i.e. holds no value).
    var isEmpty: Bool {
        return self.data == (0, 0, 0)
    }

    /// Creates a container that boxes the value at the given pointer under the given type metadata.
    ///
    /// The value is copied from `valuePtr` using the type's value-witness table. If the type
    /// is too large to fit in the 24-byte inline buffer, a heap box is allocated automatically.
    ///
    /// - Parameters:
    ///   - valuePtr: A pointer to the start of the value's storage to copy from.
    ///   - type: The Echo `Metadata` describing the boxed value's type.
    init(boxing valuePtr: RawPointer, type: Metadata) {
        self = .init(metadata: type)
        self.store(value: valuePtr)
    }

    /// Creates an existential container holding `Optional<T>.none` for an enum-based optional.
    ///
    /// Uses `_openExistential` to produce the correct typed nil rather than zeroing memory,
    /// since zero-bytes represent `.some(0)` for types like `Optional<Int>`.
    ///
    /// - Parameter optionalType: The `EnumMetadata` for the `Optional<Wrapped>` type.
    init(nil optionalType: EnumMetadata) {
        let wrappedMeta = optionalType.genericMetadata.first!
        func makeNil<T>(_: T.Type) -> AnyExistentialContainer {
            container(for: Optional<T>.none as Any)
        }
        self = _openExistential(wrappedMeta.type, do: makeNil(_:))
    }

    /// Creates an existential container holding `Optional<T>.none` for a class optional.
    ///
    /// For class optionals, nil is represented as a null pointer (all-zeros), so zeroing
    /// the inline buffer via `zeroMemory()` is correct and avoids the overhead of
    /// `_openExistential`.
    ///
    /// - Parameter optionalType: The `ClassMetadata` for the optional class type.
    init(nil optionalType: ClassMetadata) {
        self = .init(metadata: optionalType)
        self.zeroMemory()
    }

    /// Copies the value at the given pointer into this container's value buffer.
    ///
    /// The copy is performed using the container metadata's value-witness `initializeWithCopy`.
    ///
    /// - Parameter newValuePtr: A pointer to the source value to copy.
    mutating func store(value newValuePtr: RawPointer) {
        self.metadata.vwt.initializeWithCopy(self.getValueBuffer(), newValuePtr)
    }

    /// Returns a pointer to this container's value buffer, allocating a heap box first if
    /// the type is too large to fit in the 24-byte inline buffer.
    ///
    /// If the type's `isValueInline` VWT flag is `false` and no box has been allocated yet,
    /// `allocateBoxForExistential` is called to create one. Otherwise, `projectValue()` is
    /// returned directly.
    ///
    /// - Returns: A `RawPointer` to the container's value storage (inline or heap).
    mutating func getValueBuffer() -> RawPointer {
        // Allocate a box if needed and return it
        if !self.metadata.vwt.flags.isValueInline && self.data.0 == 0 {
            return self.metadata.allocateBoxForExistential(in: &self)~
        }

        // We don't need a box or already have one
        return self.projectValue()~
    }

    /// Fills this container's value buffer with zero bytes.
    ///
    /// Correct for class optionals (null pointer == all-zeros) but produces `.some(0)` for
    /// value-type optionals. Prefer ``init(nil:)-enum`` for value-type optionals.
    mutating func zeroMemory() {
        let size = self.metadata.vwt.size
        self.getValueBuffer().initializeMemory(
            as: Int8.self, repeating: 0, count: size
        )
    }
}

extension FieldRecord: @retroactive CustomDebugStringConvertible {
    /// A debug description showing the field name, mangled type name, reference storage, and flags.
    public var debugDescription: String {
        let ptr = self.mangledTypeName.assumingMemoryBound(to: UInt8.self)
        return self.name + ": \(String(cString: ptr)) ( \(self.referenceStorage) : \(self.flags))"
    }
}

extension EnumMetadata {
    /// The metadata for the `Wrapped` type of an `Optional<Wrapped>` enum.
    ///
    /// `nil` for enum types that are not optionals.
    fileprivate var optionalType: Metadata! { self.genericMetadata.first }

    /// Returns the discriminator tag for the given enum instance.
    ///
    /// The tag identifies which case is active. For payload cases the tag matches the
    /// case's index in `descriptor.fields.records`; no-payload cases have tags ≥ `numPayloadCases`.
    ///
    /// - Parameter instance: An `Any`-boxed enum value.
    /// - Returns: The `UInt32` tag for the active case.
    func getTag(for instance: Any) -> UInt32 {
        var box = container(for: instance)
        return self.enumVwt.getEnumTag(for: box.projectValue())
    }

    /// Copies the payload of the active enum case out of the given instance, if any.
    ///
    /// Returns `nil` for no-payload cases. For payload cases, the payload is wrapped
    /// in an ``AnyExistentialContainer`` and returned alongside its type.
    ///
    /// - Parameter instance: An `Any`-boxed enum value.
    /// - Returns: A `(value: Any, type: Any.Type)` tuple with the payload and its type,
    ///   or `nil` if the active case has no associated value.
    func copyPayload(from instance: Any) -> (value: Any, type: Any.Type)? {
        let tag = self.getTag(for: instance)
        let isPayloadCase = self.descriptor.numPayloadCases > tag
        if isPayloadCase {
            let caseRecord = self.descriptor.fields.records[Int(tag)]
            let type = self.type(of: caseRecord.mangledTypeName)!
            var caseBox = container(for: instance)
            // Copies in the value and allocates a box as needed
            let payload = AnyExistentialContainer(
                boxing: caseBox.projectValue()~,
                type: reflect(type)
            )
            return (unsafeBitCast(payload, to: Any.self), type)
        }

        return nil
    }
}

extension ProtocolDescriptor {
    /// The unqualified name of this protocol as declared in source.
    var description: String {
        return self.name
    }
}

extension FunctionMetadata {
    /// A Swift-style type signature string for this function type, e.g. `"(Int, String) -> Bool"`.
    var typeSignature: String {
        let params = self.paramMetadata.map(\.description).joined(separator: ", ")
        return "(" + params + ") -> " + self.resultMetadata.description
    }
}

extension TupleMetadata {
    /// A Swift-style labeled tuple signature, e.g. `"(id: Int, name: String)"`.
    var signature: String {
        let pairs = zip(self.labels, self.elements)
        return "(" + pairs.map { "\($0): \($1.metadata.description)" }.joined(separator: ", ") + ")"
    }
}

extension NominalType {
    /// A human-readable description of this nominal type.
    ///
    /// Currently delegates to `"\(self.type)"` which includes module qualification.
    /// Generic specializations are represented by Swift's default type description.
    var genericDescription: String {
        return "\(self.type)"
//        let generics = self.genericMetadata.map(\.description).joined(separator: ", ")
//        guard !generics.isEmpty else {
//            return "\(self.type)"
//        }
//
//        return "\(self.type)<\(generics)>"
    }
}

extension Metadata {
    /// A human-readable description of this type's kind and structure.
    ///
    /// - Classes, structs, and enums: the generic type description (e.g. `"Counter<Int>"`).
    /// - Optionals: the wrapped type description followed by `"?"`.
    /// - Tuples: a labeled tuple signature (e.g. `"(id: Int, name: String)"`).
    /// - Functions: a type signature (e.g. `"(Int) -> Bool"`).
    /// - Existentials: a protocol composition string (e.g. `"Equatable & Hashable"`),
    ///   or just `"Any"` / `"AnyObject"` for the top existentials.
    /// - Metatypes: the instance type description followed by `".self"`.
    /// - Internal/opaque kinds: a tilde-prefixed debug label.
    var description: String {
        switch self.kind {
            case .class, .struct, .enum:
                return "\((self as! NominalType).genericDescription)"
            case .optional:
                return "\(self.enum.optionalType!.description)?"
            case .foreignClass:
                return "~ForeignClass"
            case .opaque:
                return "~Opaque"
            case .tuple:
                return (self as! TupleMetadata).signature
            case .function:
                return (self as! FunctionMetadata).typeSignature
            case .existential:
                if self.ptr~ == Any.self~ || self.ptr~ == AnyObject.self~ {
                    return "\(self.type)"
                }

                let ext = (self as! ExistentialMetadata)
                let protocols = ext.protocols.map(\.description).joined(separator: " & ")
                if let supercls = ext.superclassMetadata {
                    return supercls.description + " & " + protocols
                } else {
                    return protocols
                }
            case .metatype:
                return (self as! MetatypeMetadata).instanceMetadata.description + ".self"
            case .objcClassWrapper:
                return "~ObjcClassWrapper"
            case .existentialMetatype:
                if self.ptr~ == AnyClass.self~ {
                    return "AnyClass"
                }
                return "~Existential"
            case .heapLocalVariable:
                return "~HLV"
            case .heapGenericLocalVariable:
                return "~HGLV"
            case .errorObject:
                return "~ErrorObject"
        }
    }
}
