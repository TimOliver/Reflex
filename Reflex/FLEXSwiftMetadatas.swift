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

extension SwiftMirror {
    static func imagePath(for pointer: UnsafeRawPointer) -> String? {
        var exeInfo = Dl_info()
        if (dladdr(pointer, &exeInfo) != 0) {
            if let fname = exeInfo.dli_fname {
                return String(cString: fname)
            }
        }
        
        return nil
    }
}

@objc(FLEXSwiftIvar)
public class SwiftIvar: FLEXIvar {
    
    convenience init(field: Field, class: ClassMetadata) {
        self.init(
            field: field,
            offset: `class`.fieldOffset(for: field.name)!,
            parent: `class`
        )
    }
    
    init(field: Field, offset: Int, parent: Metadata) {
        self.property = field
        self._offset = offset
        self._imagePath = SwiftMirror.imagePath(for: parent.ptr)
    }
    
    public override var name: String { self.property.name }
    public override var type: FLEXTypeEncoding { _typeChar }
    public override var typeEncoding: String { _typeEncodingString }
    public override var offset: Int { _offset }
    public override var size: UInt { UInt(self.property.type.vwt.size) }
    public override var imagePath: String? { self._imagePath }
    
    private let property: Field
    private let _offset: Int
    private let _imagePath: String?
    
    private lazy var _typeChar = self.property.type.typeEncoding
    private lazy var _typeEncodingString = self.property.type.typeEncodingString
    
    public override var details: String {
        "\(size) bytes, \(offset), \(typeEncoding)"
    }
    
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
    
    public override func getValue(_ target: Any) -> Any? {
        // Target must be AnyObject for KVC to work
        let target = target as AnyObject
        let type = reflect(target) as! ClassMetadata
        
        return type.getValueBox(forKey: self.name, from: target).toAny
    }
    
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
    
    public override func getPotentiallyUnboxedValue(_ target: Any) -> Any? {
        return self.getValue(target)
    }
    
    public override func auxiliaryInfo(forKey key: String) -> Any? {
        switch key {
            case FLEXAuxiliarynfoKeyFieldLabels:
                return self.structFieldNamesDict(from: self.property.type.struct)
            default:
                return nil
        }
    }
    
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

@objc(FLEXSwiftProtocol)
public class SwiftProtocol: FLEXProtocol {
    private let `protocol`: ProtocolDescriptor
    
    init(protocol ptcl: ProtocolDescriptor) {
        self.protocol = ptcl
        
        super.init()
    }
    
    public override var name: String {
        return self.protocol.name
    }
    
    public override var objc_protocol: Protocol {
        NSProtocolFromString(self.protocol.name) ?? NSObjectProtocol.self
    }

    private lazy var _imagePath: String? = {
        var exeInfo = Dl_info()
        if dladdr(self.protocol.ptr, &exeInfo) != 0, let fname = exeInfo.dli_fname {
            return String(cString: fname)
        }
        return nil
    }()

    private lazy var _inheritedProtocols: [ProtocolDescriptor] = {
        self.protocol.requirementSignature
            .filter { $0.flags.kind == .protocol }
            .map { $0.protocol }
    }()

    private lazy var _objcProtocol: FLEXProtocol? = {
        guard let p = NSProtocolFromString(self.protocol.name) else { return nil }
        return FLEXProtocol(p)
    }()

    public override var imagePath: String? { self._imagePath }

    public override var protocols: [FLEXProtocol] { _inheritedProtocols.map(SwiftProtocol.init(protocol:)) }
    public override var requiredMethods: [FLEXMethodDescription] { _objcProtocol?.requiredMethods ?? [] }
    public override var optionalMethods: [FLEXMethodDescription] { _objcProtocol?.optionalMethods ?? [] }

    public override var requiredProperties: [FLEXProperty] { _objcProtocol?.requiredProperties ?? [] }
    public override var optionalProperties: [FLEXProperty] { _objcProtocol?.optionalProperties ?? [] }
}
