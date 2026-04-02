//
//  FLEXSwiftMetadatas.swift
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

import FLEX
import Echo

/// A `FLEXIvar`-compatible representation of a single stored Swift field.
///
/// `SwiftIvar` bridges Echo's `Field` (a name–metadata pair) into the FLEX ivar model.
/// It is exposed to Objective-C as `FLEXSwiftIvar` and participates in the normal
/// FLEX property/ivar inspection UI alongside ObjC ivars.
///
/// Getting and setting values goes through `ClassMetadata.getValueBox` and
/// `ClassMetadata.set`, which handle superclass traversal and bridged-type casting.
@objc(FLEXSwiftIvar)
public class SwiftIvar: FLEXIvar {

    /// Creates a `SwiftIvar` for a field declared directly on the given class.
    ///
    /// The field's byte offset is resolved from `class`'s field-offset table.
    ///
    /// - Parameters:
    ///   - field: The name–metadata pair for the Swift field.
    ///   - class: The `ClassMetadata` that directly declares this field.
    convenience init(field: Field, class: ClassMetadata) {
        self.init(
            field: field,
            offset: `class`.fieldOffset(for: field.name)!,
            parent: `class`
        )
    }

    /// Designated initializer. Creates a `SwiftIvar` with an explicit byte offset
    /// and parent metadata for image-path lookup.
    ///
    /// - Parameters:
    ///   - field: The name–metadata pair for the Swift field.
    ///   - offset: The byte offset of this field within an instance of its declaring class.
    ///   - parent: The `Metadata` of the declaring type, used to resolve the image path.
    init(field: Field, offset: Int, parent: Metadata) {
        self.property = field
        self._offset = offset
        self._imagePath = SwiftMirror.imagePath(for: parent.ptr)
    }

    /// The unqualified field name as it appears in source.
    public override var name: String { self.property.name }

    /// The coarse-grained FLEX type encoding character for this field's type.
    public override var type: FLEXTypeEncoding { _typeChar }

    /// The full Objective-C type encoding string for this field's type.
    public override var typeEncoding: String { _typeEncodingString }

    /// The byte offset of this field within an instance of its declaring class.
    public override var offset: Int { _offset }

    /// The storage size of this field's type in bytes.
    public override var size: UInt { UInt(self.property.type.vwt.size) }

    /// The file-system path of the binary image that defines this field's declaring type,
    /// or `nil` if the image cannot be determined.
    public override var imagePath: String? { self._imagePath }

    private let property: Field
    private let _offset: Int
    private let _imagePath: String?

    private lazy var _typeChar = self.property.type.typeEncoding
    private lazy var _typeEncodingString = self.property.type.typeEncodingString

    /// A concise detail string showing the field's size, offset, and type encoding.
    public override var details: String {
        "\(size) bytes, \(offset), \(typeEncoding)"
    }

    /// Returns a human-readable declaration string for this ivar.
    ///
    /// For custom struct fields, the struct type name is used directly (e.g. `"Size cubicleSize"`).
    /// For Foundation-bridged types (e.g. `String`), the pointer star from the ObjC description
    /// is removed to produce `"String foo"` rather than `"String *foo"`.
    /// All other fields delegate to `super.description()`.
    public override func description() -> String {
        if self.type == .structBegin, let structMetadata = self.property.type as? StructMetadata {
            return "\(structMetadata.description) \(self.name)"
        }

        let desc = super.description()
        // Make things like `String *foo` appear as `String foo`
        if self.property.type.isNonTriviallyBridgedToObjc {
            return desc.replacingOccurrences(of: " *", with: " ")
        }

        return desc
    }

    /// Returns the current value of this field read from the given object.
    ///
    /// The target is cast to `AnyObject` and the value is retrieved via
    /// `ClassMetadata.getValueBox`, which handles superclass traversal.
    ///
    /// - Parameter target: The class instance to read from.
    /// - Returns: The field's current value boxed as `Any`, or `nil` if unavailable.
    public override func getValue(_ target: Any) -> Any? {
        // Target must be AnyObject for KVC to work
        let target = target as AnyObject
        let type = reflect(target) as! ClassMetadata

        return type.getValueBox(forKey: self.name, from: target).toAny
    }

    /// Writes a new value (or nil) into this field on the given object.
    ///
    /// When `value` is non-nil, delegates to `ClassMetadata.set` which handles
    /// superclass traversal and bridged-type dynamic casts.
    ///
    /// When `value` is `nil`, the correct nil representation is synthesized depending
    /// on the field's kind:
    /// - `.optional` — uses `_openExistential` to produce a properly-typed `Optional.none`
    ///   (zeroing memory would produce `.some(0)` for value-type optionals).
    /// - `.enum` — uses `AnyExistentialContainer(nil:)` for enum metadata.
    /// - `.class` — uses `AnyExistentialContainer(nil:)` for class metadata (null pointer).
    /// - Any other kind — traps, as nil assignment is not supported.
    ///
    /// - Parameters:
    ///   - value: The new value to assign, or `nil` to clear an optional/class field.
    ///   - target: The class instance to write to.
    public override func setValue(_ value: Any?, on target: Any) {
        // Target must be AnyObject for KVC to work
        let target = target as AnyObject
        let type = reflect(target) as! ClassMetadata

        if let value = value {
            // Not nil, nothing to do here
            type.set(value: value, forKey: self.name, pointer: target~)
        } else {
            // Value was nil; only supported on optional types or class types
            let kind = self.property.type.kind
            let nilValue: Any

            switch kind {
                case .optional:
                    // Zeroing memory gives the wrong result: for Optional<Int>, all-zeros
                    // means .some(0). Use _openExistential to create a properly-typed nil.
                    let wrappedMeta = (self.property.type as! EnumMetadata).genericMetadata.first!
                    func makeNil<T>(_: T.Type) -> Any { Optional<T>.none as Any }
                    nilValue = _openExistential(wrappedMeta.type, do: makeNil(_:))
                case .enum:
                    nilValue = AnyExistentialContainer(nil: self.property.type as! EnumMetadata).toAny
                case .class:
                    nilValue = AnyExistentialContainer(nil: self.property.type as! ClassMetadata).toAny
                default:
                    fatalError("Attempting to set nil to non-optional property")
            }

            type.set(value: nilValue, forKey: self.name, pointer: target~)
        }

    }

    /// Returns the value of this field without any additional unboxing.
    ///
    /// Delegates directly to ``getValue(_:)``.
    ///
    /// - Parameter target: The class instance to read from.
    /// - Returns: The field's current value boxed as `Any`, or `nil` if unavailable.
    public override func getPotentiallyUnboxedValue(_ target: Any) -> Any? {
        return self.getValue(target)
    }

    /// Returns auxiliary information for the given FLEX metadata key.
    ///
    /// Currently supports `FLEXAuxiliarynfoKeyFieldLabels`, which returns a nested
    /// dictionary mapping each struct field's type encoding string to an array of
    /// `"Type fieldName"` label strings. This is used by FLEX to display struct fields
    /// inline in the inspector.
    ///
    /// - Parameter key: A FLEX auxiliary-info key constant.
    /// - Returns: The auxiliary value for `key`, or `nil` if the key is not recognized.
    public override func auxiliaryInfo(forKey key: String) -> Any? {
        switch key {
            case FLEXAuxiliarynfoKeyFieldLabels:
                return self.structFieldNamesDict(from: self.property.type.struct)
            default:
                return nil
        }
    }

    /// Recursively builds a dictionary mapping each struct field's type encoding string
    /// to an array of `"Type fieldName"` label strings for FLEX's struct inspector.
    ///
    /// The dictionary covers the top-level struct and any nested custom struct fields
    /// (primitives and bridged types are not recursed into).
    ///
    /// - Parameter metadata: The root `StructMetadata` to describe, or `nil` to return empty.
    /// - Returns: A `[String: [String]]` mapping type encoding → field label array.
    private func structFieldNamesDict(from metadata: StructMetadata?) -> [String: [String]] {
        guard let metadata = metadata else { return [:] }

        func typeAndLabels(from metadata: StructMetadata) -> (String, [String]) {
            let key = metadata.typeEncodingString
            let labels = metadata.fields.map { "\($0.type.description) \($0.name)" }
            return (key, labels)
        }

        func recurse(into metadata: StructMetadata, mapping: inout [String: [String]]) {
            let (key, labels) = typeAndLabels(from: metadata)
            guard mapping[key] == nil else { return }
            mapping[key] = labels
            for field in metadata.fields {
                // Only recurse into nested custom structs; skip primitives and bridged types
                if let child = field.type.struct, child.typeEncoding == .structBegin {
                    recurse(into: child, mapping: &mapping)
                }
            }
        }

        var mapping: [String: [String]] = [:]
        recurse(into: metadata, mapping: &mapping)
        return mapping
    }
}

fileprivate extension Metadata {
    var `struct`: StructMetadata? { self as? StructMetadata }
}

/// A `FLEXProtocol`-compatible representation of a Swift protocol conformance.
///
/// `SwiftProtocol` bridges Echo's `ProtocolDescriptor` into the FLEX protocol model
/// and is exposed to Objective-C as `FLEXSwiftProtocol`. Where an ObjC `Protocol`
/// object exists for the same name, its required/optional methods and properties are
/// surfaced; otherwise those lists are empty.
@objc(FLEXSwiftProtocol)
public class SwiftProtocol: FLEXProtocol {
    private let `protocol`: ProtocolDescriptor

    /// Creates a `SwiftProtocol` wrapping the given Echo protocol descriptor.
    ///
    /// - Parameter ptcl: The `ProtocolDescriptor` from Echo's runtime metadata.
    init(protocol ptcl: ProtocolDescriptor) {
        self.protocol = ptcl

        super.init()
    }

    /// The unqualified name of this protocol as declared in source.
    public override var name: String {
        return self.protocol.name
    }

    /// The ObjC `Protocol` object for this protocol, or `NSObjectProtocol` as a fallback
    /// when no ObjC protocol with the same name is registered.
    public override var objc_protocol: Protocol {
        NSProtocolFromString(self.protocol.name) ?? NSObjectProtocol.self
    }

    /// The file-system path of the binary image that defines this protocol,
    /// or `nil` if the image cannot be determined.
    private lazy var _imagePath: String? = {
        var exeInfo = Dl_info()
        if dladdr(self.protocol.ptr, &exeInfo) != 0, let fname = exeInfo.dli_fname {
            return String(cString: fname)
        }
        return nil
    }()

    /// The protocol descriptors for any protocols this protocol inherits from,
    /// derived from the requirement signature's protocol requirements.
    private lazy var _inheritedProtocols: [ProtocolDescriptor] = {
        self.protocol.requirementSignature
            .filter { $0.flags.kind == .protocol }
            .map { $0.protocol }
    }()

    /// A `FLEXProtocol` wrapping the ObjC protocol of the same name, if one exists.
    ///
    /// Used to source method and property lists from the ObjC runtime.
    private lazy var _objcProtocol: FLEXProtocol? = {
        guard let p = NSProtocolFromString(self.protocol.name) else { return nil }
        return FLEXProtocol(p)
    }()

    public override var imagePath: String? { self._imagePath }

    /// The protocols inherited by this protocol, each wrapped in a `SwiftProtocol`.
    public override var protocols: [FLEXProtocol] { _inheritedProtocols.map(SwiftProtocol.init(protocol:)) }

    /// The required instance methods declared by this protocol's ObjC counterpart,
    /// or an empty array if no ObjC protocol with this name exists.
    public override var requiredMethods: [FLEXMethodDescription] { _objcProtocol?.requiredMethods ?? [] }

    /// The optional instance methods declared by this protocol's ObjC counterpart,
    /// or an empty array if no ObjC protocol with this name exists.
    public override var optionalMethods: [FLEXMethodDescription] { _objcProtocol?.optionalMethods ?? [] }

    /// The required properties declared by this protocol's ObjC counterpart,
    /// or an empty array if no ObjC protocol with this name exists.
    public override var requiredProperties: [FLEXProperty] { _objcProtocol?.requiredProperties ?? [] }

    /// The optional properties declared by this protocol's ObjC counterpart,
    /// or an empty array if no ObjC protocol with this name exists.
    public override var optionalProperties: [FLEXProperty] { _objcProtocol?.optionalProperties ?? [] }
}
